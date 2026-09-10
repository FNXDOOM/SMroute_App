import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/assigned_vehicle.dart';
import '../models/ride_option.dart';
import '../models/ride_request_record.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

enum BookingStage { matching, found, arriving, completed, cancelled }

class RideProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  String? _destination;
  RideOption? _selectedOption;
  BookingStage _stage = BookingStage.matching;
  bool _isBooking = false;
  bool _isLoadingRides = false;
  String? _error;
  final List<RideRequestRecord> _myRides = [];

  // Vehicle assignment (F2/F3) — the ride just booked, and whichever real
  // vehicle the backend's route optimizer eventually assigns to it.
  int? _currentRideId;
  AssignedVehicle? _assignedVehicle;
  Timer? _vehiclePollTimer;
  int _vehiclePollAttempts = 0;
  bool _vehicleAssignmentTimedOut = false;
  bool _isFetchingVehicle = false;
  WebSocketChannel? _trackingChannel;
  StreamSubscription? _trackingSubscription;

  // Backend has no automatic job that actually runs route optimization /
  // vehicle assignment for a ride — only a timer-driven status simulation.
  // So a real vehicle may never show up. Stop polling after this many
  // attempts (~2 min at 4s/poll) rather than polling forever.
  static const int _maxVehiclePollAttempts = 30;

  String? get destination => _destination;
  RideOption? get selectedOption => _selectedOption;
  BookingStage get stage => _stage;
  bool get isBooking => _isBooking;
  bool get isLoadingRides => _isLoadingRides;
  String? get error => _error;
  List<RideRequestRecord> get myRides => List.unmodifiable(_myRides);
  AssignedVehicle? get assignedVehicle => _assignedVehicle;
  bool get vehicleAssignmentTimedOut => _vehicleAssignmentTimedOut;
  int? get currentRideId => _currentRideId;

  /// Terminal states stop vehicle polling/tracking; UI can show receipt.
  bool get isRideTerminal =>
      _stage == BookingStage.completed || _stage == BookingStage.cancelled;

  void setDestination(String d) {
    _destination = d;
    _error = null;
    notifyListeners();
  }

  void selectOption(RideOption r) {
    _selectedOption = r;
    _error = null;
    notifyListeners();
  }

  String _messageForException(Object error) {
    if (error is ApiException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  static int? _parseRideId(dynamic raw) {
    if (raw is int) return raw;
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  static double? _parseCoord(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  void handleRideStatusUpdate(String newStatus) {
    switch (newStatus) {
      case 'assigned':
        _stage = BookingStage.found;
        break;
      case 'arriving':
        _stage = BookingStage.arriving;
        break;
      case 'in_progress':
        // Treat "driver on trip" as still arriving for ETA display.
        _stage = BookingStage.arriving;
        break;
      case 'completed':
        _stage = BookingStage.completed;
        _stopVehicleTracking(keepAttempts: true);
        break;
      case 'cancelled':
        _stage = BookingStage.cancelled;
        _stopVehicleTracking(keepAttempts: true);
        break;
      default:
        return;
    }
    notifyListeners();
  }

  Future<bool> confirmBooking() async {
    if (_destination == null || _destination!.trim().isEmpty) {
      _error = 'Please choose a destination first.';
      notifyListeners();
      return false;
    }
    if (_selectedOption == null) {
      _error = 'Please select a ride option first.';
      notifyListeners();
      return false;
    }

    _isBooking = true;
    _error = null;
    _stage = BookingStage.matching;
    _assignedVehicle = null;
    _vehiclePollAttempts = 0;
    _vehicleAssignmentTimedOut = false;
    _isFetchingVehicle = false;
    _stopVehicleTracking();
    notifyListeners();

    try {
      final pickup = LocationService.defaultPickup;
      final destinationPoint = LocationService.geocode(_destination!);
      final response = await _api.postJson(
        '/rides/request',
        body: {
          'pickup_lat': pickup.lat,
          'pickup_lng': pickup.lng,
          'dest_lat': destinationPoint.lat,
          'dest_lng': destinationPoint.lng,
          'ride_option_id': _selectedOption!.id,
          'ride_option_name': _selectedOption!.name,
          'ride_option_price': _selectedOption!.priceRange,
          'pickup_label': 'Current location',
          'destination_label': _destination,
        },
      );
      final created = response as Map<String, dynamic>?;
      _currentRideId = _parseRideId(created?['id']);
      if (_currentRideId == null) {
        _error = 'Booking created but no ride id was returned.';
        notifyListeners();
        return false;
      }
      _startVehiclePolling();
      await loadMyRides(silent: true);
      return true;
    } catch (error) {
      _error = _messageForException(error);
      notifyListeners();
      return false;
    } finally {
      _isBooking = false;
      notifyListeners();
    }
  }

  Future<void> loadMyRides({bool silent = false}) async {
    if (!silent) {
      _isLoadingRides = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await _api.getJson('/rides/my-rides');
      final raw = response as List<dynamic>? ?? const [];
      final items = <RideRequestRecord>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          items.add(RideRequestRecord.fromJson(entry));
        } on FormatException {
          // Skip malformed records instead of failing the whole list.
          continue;
        }
      }
      _myRides
        ..clear()
        ..addAll(items);
      // Silent loads still change data — listeners (Trips badge/history)
      // must rebuild, just without the loading spinner.
      notifyListeners();
    } catch (error) {
      if (!silent) {
        _error = _messageForException(error);
        notifyListeners();
      }
    } finally {
      if (!silent) {
        _isLoadingRides = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    _destination = null;
    _selectedOption = null;
    _stage = BookingStage.matching;
    _error = null;
    _currentRideId = null;
    _assignedVehicle = null;
    _vehiclePollAttempts = 0;
    _vehicleAssignmentTimedOut = false;
    _isFetchingVehicle = false;
    _stopVehicleTracking();
    notifyListeners();
  }

  /// Clears ride-booking state without touching destination history —
  /// used on logout to avoid leaking one account's trip into the next.
  void clearForLogout() {
    reset();
    _myRides.clear();
  }

  // ── Vehicle assignment (F2) + live position (F3) ─────────────────────────

  /// Polls `GET /rides/{id}/vehicle` every few seconds until a vehicle is
  /// assigned. The backend's automatic dispatch simulation advances ride
  /// *status* on a timer regardless of whether a real vehicle/route was
  /// ever assigned (route optimization is a manual, admin/driver-only
  /// trigger) — so this polling isn't guaranteed to ever resolve. Gives up
  /// after `_maxVehiclePollAttempts` rather than polling forever, and sets
  /// `vehicleAssignmentTimedOut` so the UI can show a clear message instead
  /// of an indefinite "Assigning a vehicle…" spinner state.
  void _startVehiclePolling() {
    _vehiclePollTimer?.cancel();
    _vehiclePollAttempts = 0;
    _vehicleAssignmentTimedOut = false;
    _isFetchingVehicle = false;
    _vehiclePollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      // Guard against overlapping requests when the backend is slow.
      if (_isFetchingVehicle) return;
      await _fetchAssignedVehicle();
    });
    // Fire once immediately rather than waiting for the first tick.
    unawaited(_fetchAssignedVehicle());
  }

  Future<void> _fetchAssignedVehicle() async {
    final rideId = _currentRideId;
    if (rideId == null || _isFetchingVehicle) return;
    _isFetchingVehicle = true;
    try {
      final response = await _api.getJson('/rides/$rideId/vehicle');
      if (response is Map<String, dynamic>) {
        final vehicle = AssignedVehicle.fromJson(response);
        if (vehicle.id == -1) {
          // Malformed vehicle payload — keep polling.
          _notePollAttempt();
          return;
        }
        _assignedVehicle = vehicle;
        _vehiclePollTimer?.cancel();
        _vehiclePollTimer = null;
        _connectVehicleTracking();
        notifyListeners();
        return;
      }
      // response == null means no route optimized yet — keep polling until
      // the attempt cap below.
      _notePollAttempt();
    } catch (_) {
      // Transient errors (e.g. backend briefly unavailable) — count toward
      // the same cap but don't surface as a user-facing error for a
      // background refresh.
      _notePollAttempt();
    } finally {
      _isFetchingVehicle = false;
    }
  }

  void _notePollAttempt() {
    _vehiclePollAttempts++;
    if (_vehiclePollAttempts >= _maxVehiclePollAttempts) {
      _vehiclePollTimer?.cancel();
      _vehiclePollTimer = null;
      _vehicleAssignmentTimedOut = true;
      notifyListeners();
    }
  }

  /// Opens `/tracking/ws` and filters the broadcast vehicle snapshot down to
  /// just the one assigned to this ride, updating its live lat/lng.
  void _connectVehicleTracking() {
    if (_trackingChannel != null) return;
    final vehicle = _assignedVehicle;
    if (vehicle == null) return;

    unawaited(() async {
      final token = await _api.token;
      if (token == null || token.isEmpty) return;
      final wsUrl = _api.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsUrl/tracking/ws').replace(
        queryParameters: {'token': token},
      );
      _trackingChannel = WebSocketChannel.connect(uri);
      _trackingSubscription = _trackingChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            List<dynamic>? vehicles;
            if (data['type'] == 'tracking_snapshot') {
              vehicles = data['vehicles'] as List<dynamic>?;
            } else if (data['type'] == 'vehicle_location_update' &&
                data['vehicle'] is Map<String, dynamic>) {
              vehicles = [data['vehicle']];
            }
            if (vehicles == null) return;
            Map<String, dynamic>? match;
            for (final v in vehicles) {
              if (v is! Map<String, dynamic>) continue;
              if (v['id']?.toString() == _assignedVehicle?.id.toString()) {
                match = v;
                break;
              }
            }
            if (match != null) {
              final current = _assignedVehicle;
              if (current == null) return;
              _assignedVehicle = current.copyWithLocation(
                lat: _parseCoord(match['lat']),
                lng: _parseCoord(match['lng']),
                status: match['status']?.toString(),
              );
              notifyListeners();
            }
          } catch (_) {
            // Ignore malformed socket payloads.
          }
        },
        onError: (_) => _stopVehicleTracking(),
        onDone: () => _stopVehicleTracking(),
        cancelOnError: false,
      );
    }());
  }

  void _stopVehicleTracking({bool keepAttempts = false}) {
    _vehiclePollTimer?.cancel();
    _vehiclePollTimer = null;
    if (!keepAttempts) _vehiclePollAttempts = 0;
    _isFetchingVehicle = false;
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    try {
      _trackingChannel?.sink.close();
    } catch (_) {
      // Socket may already be closed.
    }
    _trackingChannel = null;
  }

  @override
  void dispose() {
    _stopVehicleTracking();
    super.dispose();
  }
}
