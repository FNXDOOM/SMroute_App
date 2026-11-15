import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/carpool_stage.dart';
import '../models/ride_request_record.dart';
import '../models/shared_route.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/carpool_service.dart';
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
  DriverProvider(this._auth, {DriverService? service})
      : _service = service ?? DriverService.instance;

  AuthProvider _auth;

  /// Re-points the provider at the current AuthProvider instance after a
  /// login/logout (the proxy provider supplies the newest one).
  // ignore: use_setters_to_change_properties
  void refreshAuth(AuthProvider auth) => _auth = auth;
  final DriverService _service;
  final CarpoolService _carpool = CarpoolService.instance;

  List<DriverVehicle> _vehicles = [];
  DriverVehicle? _myVehicle;
  List<RideRequestRecord> _board = [];
  bool _isLoading = false;
  bool _isBusy = false; // any single in-flight mutation
  bool _isUpdatingLocation = false;
  String? _error;
  bool _isLoaded = false;
  bool _disposed = false;

  // ── Assigned pooled route ─────────────────────────────────────────────────
  // The optimizer writes the route's id onto the vehicle row, so the console
  // can draw the same pooled route the passengers on it see. Resolved on the
  // existing board poll (no timer of its own) and re-resolved whenever the
  // vehicle's assignment changes.
  String? _routeKey;
  SharedRoute? _assignedRoute;
  RouteDisplayMode _routeDisplay = RouteDisplayMode.single;
  bool _isFetchingRoute = false;

  /// Statuses that mean "this ride still needs driving".
  static const Set<String> _liveRideStatuses = {
    'pending',
    'assigned',
    'arriving',
    'in_progress',
  };

  static const Set<String> _activeRideStatuses = {
    'assigned',
    'arriving',
    'in_progress',
  };

  /// Test seam: install the route the console would have fetched.
  @visibleForTesting
  void debugSetAssignedRoute(SharedRoute? route) {
    _routeKey = route?.routeId;
    _assignedRoute = route;
    _routeDisplay = RouteDisplayMode.single;
    notifyListeners();
  }

  /// Test seam: install the polled dispatch board (and, once, the vehicle this
  /// driver controls).
  @visibleForTesting
  void debugSetBoard(List<RideRequestRecord> board, {DriverVehicle? vehicle}) {
    _board = board;
    if (vehicle != null) _myVehicle = vehicle;
    notifyListeners();
  }

  // Website parity (DriverView.refreshRides): the dispatch board is polled
  // so new pending requests appear without a manual refresh. Failures keep
  // the last good list; the next tick retries.
  Timer? _boardPollTimer;
  bool _isRefreshingBoard = false;
  static const Duration _boardPollInterval = Duration(seconds: 6);

  // Presence is the dispatch availability signal (site DriverView): the
  // backend only auto-assigns routes to drivers seen within its 90 s presence
  // window and reclaims offers from drivers who went quiet. Beat on console
  // open, then every 30 s while it stays open — duty status is a separate axis.
  Timer? _presenceTimer;
  static const Duration _presenceInterval = Duration(seconds: 30);

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    unawaited(_beatPresence());
    _presenceTimer =
        Timer.periodic(_presenceInterval, (_) => unawaited(_beatPresence()));
  }

  Future<void> _beatPresence() async {
    if (_disposed) return;
    try {
      await _service.sendPresence();
    } catch (_) {
      // Best effort — the next beat retries; a missed one is tolerated.
    }
  }

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
    final rides = _board
        .where((r) => _activeRideStatuses.contains(r.status))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return rides;
  }

  /// The pooled route this driver's vehicle is running, or null when the
  /// optimizer has not assigned one (the common single-passenger case).
  SharedRoute? get assignedRoute => _assignedRoute;

  /// True when there is more than one leg to draw — the only case where the
  /// map's single-line / legs toggle is offered.
  bool get hasSegmentedRoute => _assignedRoute?.isMultiStop ?? false;

  RouteDisplayMode get routeDisplay => _routeDisplay;

  /// The vehicle's last reported position, or null before the first GPS push.
  GeoPoint? get vehiclePoint {
    final lat = _myVehicle?.lat;
    final lng = _myVehicle?.lng;
    if (lat == null || lng == null) return null;
    return GeoPoint(lat, lng);
  }

  /// The next stop to serve, in route order, with the distance from the vehicle.
  ///
  /// Stops are the pooled route's own stop list, and a ride counts as served
  /// once the board reports it as terminal — so completing a ride advances the
  /// callout to the following stop on the next poll.
  RouteNextStop? get nextStop {
    final route = _assignedRoute;
    if (route == null) return null;
    final finished = <int>{
      for (final ride in _board)
        if (!_liveRideStatuses.contains(ride.status)) ride.id,
    };
    return route.nextPendingStop(
      finishedRideIds: finished,
      from: vehiclePoint,
    );
  }

  /// Stops still to be served, in visit order (the next stop included).
  int get pendingStopCount {
    final route = _assignedRoute;
    if (route == null) return 0;
    final finished = <int>{
      for (final ride in _board)
        if (!_liveRideStatuses.contains(ride.status)) ride.id,
    };
    var count = 0;
    for (final stop in route.stops) {
      if (stop.isDepot || stop.passengerIds.isEmpty) continue;
      if (stop.passengerIds.any((rideId) => !finished.contains(rideId))) count++;
    }
    return count;
  }

  /// Switches the console map between the whole pooled line and its legs.
  void toggleRouteDisplay() {
    if (!hasSegmentedRoute) return;
    _routeDisplay = _routeDisplay == RouteDisplayMode.single
        ? RouteDisplayMode.segments
        : RouteDisplayMode.single;
    notifyListeners();
  }

  List<RideRequestRecord> get pendingRides {
    final rides = _board.where((r) => r.status == 'pending').toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return rides;
  }

  // ── Carpool run (driver) ──────────────────────────────────────────────────
  // The normal dispatch board carries private rides only; a carpool run is
  // driven from the dedicated Carpool Run screen, whose actions live here.

  /// Private rides only — what the normal dashboard must show.
  List<RideRequestRecord> get normalActiveRides => _board
      .where((r) => !r.isShared && _activeRideStatuses.contains(r.status))
      .toList()
    ..sort((a, b) => b.id.compareTo(a.id));

  List<RideRequestRecord> get normalPendingRides => _board
      .where((r) => !r.isShared && r.status == 'pending')
      .toList()
    ..sort((a, b) => b.id.compareTo(a.id));

  /// True when the assigned route is a carpool run.
  bool get hasCarpoolRun => _assignedRoute?.isCarpoolRun ?? false;

  /// Whether the driver has accepted the assigned carpool run.
  bool get carpoolAccepted => _assignedRoute?.driverAccepted ?? false;

  /// Rides served by the assigned carpool route, in rider-id order.
  List<RideRequestRecord> get carpoolRides {
    final route = _assignedRoute;
    if (route == null) return const [];
    final rideIds = <int>{
      for (final stop in route.stops) ...stop.passengerIds,
    };
    if (rideIds.isEmpty) return const [];
    return _board
        .where((ride) => ride.isShared && rideIds.contains(ride.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Riders on the run, for the "2 / 3 passengers" header.
  int get carpoolRiderCount => carpoolRides.length;

  int get carpoolCapacity => math.min(3, _myVehicle?.capacity ?? 3);

  /// Riders currently onboard (boarded or in transit).
  int get carpoolOnboardCount => carpoolRides
      .where((ride) => const {'boarded', 'in_transit'}.contains(ride.carpoolStatus))
      .length;

  /// This rider's fine carpool stage.
  CarpoolStage carpoolStageFor(RideRequestRecord ride) => CarpoolStage.fromRide(
        status: ride.status,
        carpoolStatus: ride.carpoolStatus,
        route: _assignedRoute,
      );

  String? get _carpoolRouteId => _assignedRoute?.routeId;

  /// Runs one carpool action, then refreshes the board and forces the route to
  /// be re-read (the action changes route metadata, which the cached plan would
  /// otherwise hide until the assignment itself changed).
  Future<bool> _runCarpoolAction(Future<void> Function() action) async {
    if (_isBusy) return false;
    _isBusy = true;
    notifyListeners();
    try {
      await action();
      _routeKey = null; // force `_ensureAssignedRoute` to re-fetch
      await _refreshBoard(silent: true);
      return true;
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Could not update the carpool run.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Driver accepts the assigned carpool run (closes it to new riders).
  Future<bool> acceptCarpoolRun() {
    final routeId = _carpoolRouteId;
    if (routeId == null) return Future.value(false);
    return _runCarpoolAction(() => _carpool.acceptRoute(routeId));
  }

  /// Driver starts heading to a rider's pickup stop.
  Future<bool> announcePickup(RideRequestRecord ride) {
    final routeId = _carpoolRouteId;
    if (routeId == null) return Future.value(false);
    return _runCarpoolAction(() => _carpool.announcePickup(routeId, ride.id));
  }

  /// Driver reached the pickup stop.
  Future<bool> markArrived(RideRequestRecord ride) {
    final routeId = _carpoolRouteId;
    if (routeId == null) return Future.value(false);
    return _runCarpoolAction(() => _carpool.markArrived(routeId, ride.id));
  }

  /// Driver confirmed the rider boarded.
  Future<bool> confirmBoarded(RideRequestRecord ride) {
    final routeId = _carpoolRouteId;
    if (routeId == null) return Future.value(false);
    return _runCarpoolAction(() => _carpool.confirmBoarded(routeId, ride.id));
  }

  /// Driver starts driving: every boarded rider moves to IN_TRANSIT.
  Future<bool> departCarpoolRun() {
    final routeId = _carpoolRouteId;
    if (routeId == null) return Future.value(false);
    return _runCarpoolAction(() => _carpool.depart(routeId));
  }

  /// Driver confirmed one rider was dropped off.
  Future<bool> confirmDropoff(RideRequestRecord ride) {
    final routeId = _carpoolRouteId;
    if (routeId == null) return Future.value(false);
    return _runCarpoolAction(() => _carpool.confirmDropoff(routeId, ride.id));
  }

  /// Driver confirms the final drop-off; the backend refuses until every rider
  /// is dropped off.
  Future<bool> completeCarpoolRun() {
    final routeId = _carpoolRouteId;
    if (routeId == null) return Future.value(false);
    return _runCarpoolAction(() => _carpool.completeRoute(routeId));
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
      _board = results[1] as List<RideRequestRecord>;
      _isLoaded = true;
      _applyVehicles(results[0] as List<DriverVehicle>);

      await _ensureAssignedRoute();
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
    _startPresenceHeartbeat();
  }

  void selectVehicle(DriverVehicle vehicle) {
    _myVehicle = vehicle;
    _error = null;
    // Another vehicle means another route (or none) — drop the old drawing and
    // resolve the new assignment straight away.
    _resetAssignedRoute();
    notifyListeners();
    _ensureAssignedRoute();
  }

  /// Adopts a fresh vehicle list, keeping "my vehicle" if it still exists and
  /// else falling back to the one registered to this driver (site: the
  /// pre-selected dropdown). Always points at the newest row, so a route the
  /// optimizer just assigned is picked up.
  void _applyVehicles(List<DriverVehicle> vehicles) {
    _vehicles = vehicles;
    final selectedId = _myVehicle?.id;
    if (selectedId != null) {
      for (final vehicle in _vehicles) {
        if (vehicle.id == selectedId) {
          _myVehicle = vehicle;
          return;
        }
      }
      _myVehicle = null;
    }
    final userId = _auth.currentUser?.id;
    if (userId == null) return;
    for (final vehicle in _vehicles) {
      if (vehicle.driverUserId == userId) {
        _myVehicle = vehicle;
        return;
      }
    }
  }

  void _resetAssignedRoute() {
    if (_routeKey == null && _assignedRoute == null) return;
    _routeKey = null;
    _assignedRoute = null;
    _routeDisplay = RouteDisplayMode.single;
  }

  /// Resolves the vehicle's pooled route, once per assignment.
  ///
  /// Best effort: a plan this driver may not read (403), one that is gone (404)
  /// or a transient failure leaves the console on the dispatch board and the
  /// next poll retries — the dispatch job may not have finished writing the
  /// route when the vehicle row first shows its id.
  Future<void> _ensureAssignedRoute() async {
    final routeId = _myVehicle?.assignedRouteId;
    if (routeId == null || routeId.isEmpty) {
      if (_assignedRoute != null || _routeKey != null) {
        _resetAssignedRoute();
        notifyListeners();
      }
      return;
    }
    // A stored key with no route means the fetch failed: retry it.
    if (_routeKey == routeId && _assignedRoute != null) return;
    if (_isFetchingRoute || _disposed) return;

    _isFetchingRoute = true;
    try {
      final plan = await _service.fetchRoutePlan(routeId);
      if (_disposed) return;
      final route = plan == null ? null : SharedRoute.fromRoutePlanJson(plan);
      final routeChanged = route?.routeId != _assignedRoute?.routeId;
      _routeKey = routeId;
      _assignedRoute = route;
      // A new route (or one with nothing to segment) starts on the whole line.
      if (routeChanged || !(route?.isMultiStop ?? false)) {
        _routeDisplay = RouteDisplayMode.single;
      }
      notifyListeners();
    } finally {
      _isFetchingRoute = false;
    }
  }

  /// Go on duty (active) / off duty (idle) — site `toggleDuty`.
  Future<bool> setDuty(bool onDuty) async {
    final vehicle = _myVehicle;
    if (vehicle == null || _isBusy) return false;
    _isBusy = true;
    notifyListeners();
    try {
      final status = onDuty ? 'active' : 'idle';
      await _service.setVehicleStatus(vehicle.id, status);
      _myVehicle = vehicle.copyWith(status: status);
      _vehicles = [
        for (final v in _vehicles)
          if (v.id == vehicle.id) v.copyWith(status: status) else v,
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
      _myVehicle = vehicle.copyWith(
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
      // The optimizer writes the route id onto the vehicle row out of band, so
      // the same tick has to re-read it — otherwise the console would only ever
      // see a pooled route the driver explicitly refreshed for.
      await _refreshVehicles();
      await _ensureAssignedRoute();
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

  /// Best effort: the board still refreshes when the vehicle list fails, and
  /// the next tick retries.
  Future<void> _refreshVehicles() async {
    try {
      _applyVehicles(await _service.listVehicles());
    } catch (_) {
      // Ignored — see above.
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
    _presenceTimer?.cancel();
    _presenceTimer = null;
    onNewPendingRide = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _boardPollTimer?.cancel();
    _boardPollTimer = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    super.dispose();
  }
}
