import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/ride_request_record.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/driver_service.dart';
import '../services/geocoding_service.dart';

/// Driver mode state — the mobile twin of the website's DriverView:
///
///   - "my vehicle" = `GET /vehicle/` filtered by `driver_user_id`, with a
///     picker fallback (the site has the same dropdown)
///   - Go on/off duty = `PATCH /vehicle/{id}` status active|idle
///   - Update location = real GPS fix → `POST /tracking/vehicles/{id}/location`
///   - Dispatch board = `GET /rides/` (limit 50); accept / arrive / complete
///     via `PATCH /rides/{id}/status`
///
/// Rides and vehicle state always come from the backend; nothing is simulated.
class DriverProvider extends ChangeNotifier {
  DriverProvider(this._auth);

  AuthProvider _auth;

  /// Re-points the provider at the current AuthProvider instance after a
  /// login/logout (the proxy provider supplies the newest one).
  // ignore: use_setters_to_change_properties
  void refreshAuth(AuthProvider auth) => _auth = auth;
  final DriverService _service = DriverService.instance;

  List<DriverVehicle> _vehicles = [];
  DriverVehicle? _myVehicle;
  List<RideRequestRecord> _board = [];
  bool _isLoading = false;
  bool _isBusy = false; // any single in-flight mutation
  bool _isUpdatingLocation = false;
  String? _error;
  bool _isLoaded = false;

  // Website parity (DriverView.refreshRides): the dispatch board is polled
  // so new pending requests appear without a manual refresh. Failures keep
  // the last good list; the next tick retries.
  Timer? _boardPollTimer;
  bool _isRefreshingBoard = false;
  static const Duration _boardPollInterval = Duration(seconds: 6);

  List<DriverVehicle> get vehicles => List.unmodifiable(_vehicles);
  DriverVehicle? get myVehicle => _myVehicle;
  List<RideRequestRecord> get board => List.unmodifiable(_board);
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get isUpdatingLocation => _isUpdatingLocation;
  String? get error => _error;
  bool get isLoaded => _isLoaded;

  /// Rides a driver can act on, newest first (site: "Dispatch board").
  List<RideRequestRecord> get activeRides {
    const activeStatuses = {'assigned', 'arriving', 'in_progress'};
    final rides = _board
        .where((r) => activeStatuses.contains(r.status))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return rides;
  }

  List<RideRequestRecord> get pendingRides {
    final rides = _board.where((r) => r.status == 'pending').toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return rides;
  }

  /// Website parity (DriverView): new pending requests toast as they appear
  /// in the polled board — same shape as the site's "New ride request".
  void Function(RideRequestRecord ride)? onNewPendingRide;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Only drivers may load the dispatch board; backend 403s otherwise.
      final results = await Future.wait([
        _service.listVehicles(),
        _service.fetchBoard(),
      ]);
      _vehicles = results[0] as List<DriverVehicle>;
      _board = results[1] as List<RideRequestRecord>;
      _isLoaded = true;

      // Keep "my vehicle" if still valid, else auto-select the one
      // registered to this driver (site: pre-selected dropdown).
      final userId = _auth.currentUser?.id;
      if (_myVehicle != null &&
          !_vehicles.any((v) => v.id == _myVehicle!.id)) {
        _myVehicle = null;
      }
      if (_myVehicle == null && userId != null) {
        for (final v in _vehicles) {
          if (v.driverUserId == userId) {
            _myVehicle = v;
            break;
          }
        }
      }
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Unable to load the dispatch board.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    // First load succeeded or failed either way — start the cadence the
    // website uses so incoming requests show up unprompted.
    _startBoardPolling();
  }

  void selectVehicle(DriverVehicle vehicle) {
    _myVehicle = vehicle;
    _error = null;
    notifyListeners();
  }

  /// Go on duty (active) / off duty (idle) — site `toggleDuty`.
  Future<bool> setDuty(bool onDuty) async {
    final vehicle = _myVehicle;
    if (vehicle == null || _isBusy) return false;
    _isBusy = true;
    notifyListeners();
    try {
      await _service.setVehicleStatus(vehicle.id, onDuty ? 'active' : 'idle');
      _myVehicle = DriverVehicle(
        id: vehicle.id,
        licensePlate: vehicle.licensePlate,
        capacity: vehicle.capacity,
        status: onDuty ? 'active' : 'idle',
        driverUserId: vehicle.driverUserId,
        lat: vehicle.lat,
        lng: vehicle.lng,
      );
      _vehicles = [
        for (final v in _vehicles)
          if (v.id == vehicle.id)
            DriverVehicle(
              id: v.id,
              licensePlate: v.licensePlate,
              capacity: v.capacity,
              status: onDuty ? 'active' : 'idle',
              driverUserId: v.driverUserId,
              lat: v.lat,
              lng: v.lng,
            )
          else
            v,
      ];
      return true;
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Could not update duty status.';
      notifyListeners();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Pushes the real device GPS fix to the backend so passengers see this
  /// vehicle move on their maps (site `updateLocation`).
  Future<bool> pushMyLocation() async {
    final vehicle = _myVehicle;
    if (vehicle == null || _isUpdatingLocation) return false;

    _isUpdatingLocation = true;
    notifyListeners();
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _error = 'Location permission is required to update your position.';
        return false;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _service.pushLocation(
        vehicleId: vehicle.id,
        position: GeoPoint(position.latitude, position.longitude),
      );
      _myVehicle = DriverVehicle(
        id: vehicle.id,
        licensePlate: vehicle.licensePlate,
        capacity: vehicle.capacity,
        status: vehicle.status,
        driverUserId: vehicle.driverUserId,
        lat: position.latitude,
        lng: position.longitude,
      );
      return true;
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Could not get a GPS fix.';
      return false;
    } finally {
      _isUpdatingLocation = false;
      notifyListeners();
    }
  }

  /// Accept a pending ride (site: assign → vehicle active, ride assigned).
  Future<bool> acceptRide(RideRequestRecord ride) async {
    final vehicle = _myVehicle;
    if (vehicle == null || _isBusy) return false;
    _isBusy = true;
    notifyListeners();
    try {
      if (vehicle.status != 'active') {
        await _service.setVehicleStatus(vehicle.id, 'active');
      }
      await _service.updateRideStatus(rideId: ride.id, status: 'assigned');
      await _refreshBoard(silent: true);
      return true;
    } catch (error) {
      _error = error is ApiException ? error.message : 'Could not accept ride.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Advances an active ride: assigned → arriving → in_progress → completed.
  Future<bool> advanceRide(RideRequestRecord ride, String nextStatus) async {
    if (_isBusy) return false;
    _isBusy = true;
    notifyListeners();
    try {
      await _service.updateRideStatus(
        rideId: ride.id,
        status: nextStatus,
        vehicleId: _myVehicle?.id,
      );
      await _refreshBoard(silent: true);
      return true;
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Could not update the ride.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _refreshBoard({bool silent = true}) async {
    try {
      final previousPending = _board
          .where((r) => r.status == 'pending')
          .map((r) => r.id)
          .toSet();
      _board = await _service.fetchBoard();
      if (onNewPendingRide != null) {
        for (final ride in _board) {
          if (ride.status == 'pending' && !previousPending.contains(ride.id)) {
            onNewPendingRide!(ride);
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // Silent refresh — the next explicit load surfaces errors.
    }
  }

  void _startBoardPolling() {
    _boardPollTimer?.cancel();
    _boardPollTimer = Timer.periodic(_boardPollInterval, (_) async {
      if (_isRefreshingBoard) return;
      _isRefreshingBoard = true;
      await _refreshBoard(silent: true);
      _isRefreshingBoard = false;
    });
  }

  /// Called when the driver console closes — the site's interval only runs
  /// while its view is mounted, and an app-scoped provider must not poll
  /// forever in the background.
  void stopBoardPolling() {
    _boardPollTimer?.cancel();
    _boardPollTimer = null;
    onNewPendingRide = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _boardPollTimer?.cancel();
    _boardPollTimer = null;
    super.dispose();
  }
}
