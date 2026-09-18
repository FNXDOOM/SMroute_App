import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/assigned_vehicle.dart';
import '../models/ride_option.dart';
import '../models/ride_request_record.dart';
import '../models/ride_stage.dart';
import '../services/api_client.dart';
import '../services/geocoding_service.dart';
import '../services/razorpay_service.dart';
import '../services/routing_service.dart';

enum BookingStage { matching, found, arriving, completed, cancelled }

/// Payment state machine for the active ride's fare (website's
/// RazorpayPayment phases: idle → creating → paying → verifying → paid |
/// failed). Success is only ever derived from `POST /payments/verify`.
enum PaymentPhase {
  idle,
  creating,
  paying,
  verifying,
  paid,
  failed,
}

/// A checkout started from the app.
class PaymentFlowException implements Exception {
  PaymentFlowException(this.message);
  final String message;
}

class RideProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  String? _destination;
  GeoPoint? _destinationPoint;
  bool _isResolvingDestination = false;
  RideOption? _selectedOption;

  // ── Pickup (site: pickup field + GPS + "Choose on map") ──────────────────
  // The website never books from a fabricated pickup: the user either picks a
  // suggestion, uses GPS, or taps the map. Until then we fall back to the
  // backend's Bengaluru service point, and the UI says so.
  GeoPoint? _pickupPoint;
  String _pickupLabel = 'Current location';
  bool _pickupConfirmed = false;

  /// Site's "Use live traffic for route and ETA" switch.
  bool _trafficEnabled = false;

  /// Road route for the currently selected pickup → destination pair.
  RouteEstimate? _routeEstimate;
  bool _isLoadingRoute = false;
  String _routeKey = '';
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
  int _trackingReconnectAttempts = 0;
  Timer? _trackingReconnectTimer;
  bool _disposed = false;

  // ── Fare payment (website's RazorpayPayment on the active-ride card) ────
  PaymentPhase _paymentPhase = PaymentPhase.idle;
  String? _paymentError;
  PaymentPhase get paymentPhase => _paymentPhase;
  String? get paymentError => _paymentError;
  bool get isPaying =>
      _paymentPhase == PaymentPhase.creating ||
      _paymentPhase == PaymentPhase.paying ||
      _paymentPhase == PaymentPhase.verifying;

  /// Full website checkout flow: create-order → native checkout → verify.
  /// Returns true only after the backend confirms the payment signature.
  Future<bool> payActiveRideFare() async {
    final rideId = _currentRideId;
    final ride = activeRideRecord;
    if (rideId == null || ride == null || isPaying) return false;
    if (_paymentPhase == PaymentPhase.paid) return true;

    _paymentError = null;
    _paymentPhase = PaymentPhase.creating;
    notifyListeners();

    try {
      final checkout = await _api.postJson(
        '/payments/create-order',
        body: <String, dynamic>{
          'ride_request_id': rideId,
          'ride_option_id': ride.rideOptionId,
          'ride_option_name': ride.rideOptionName ?? 'ride fare',
        },
      );
      if (checkout is! Map<String, dynamic>) {
        throw PaymentFlowException('Unexpected payment response from server.');
      }

      if (_disposed) return false;
      _paymentPhase = PaymentPhase.paying;
      notifyListeners();

      // Opens native Checkout; completes only after /payments/verify.
      final verified = await RazorpayService.pay(checkout: checkout);
      if (_disposed) return verified;

      _paymentPhase = verified ? PaymentPhase.paid : PaymentPhase.failed;
      if (!verified) {
        _paymentError = 'The payment could not be verified. If you were '
            'charged, it will settle automatically.';
      }
      notifyListeners();
      return verified;
    } on ApiException catch (error) {
      _paymentPhase = PaymentPhase.failed;
      _paymentError = error.message;
      notifyListeners();
      return false;
    } on PaymentFlowException catch (error) {
      _paymentPhase = PaymentPhase.failed;
      _paymentError = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _paymentPhase = PaymentPhase.failed;
      _paymentError = 'Could not complete the payment. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void resetPaymentState() {
    _paymentPhase = PaymentPhase.idle;
    _paymentError = null;
    notifyListeners();
  }
  Timer? _statusPollTimer;
  bool _isPollingStatus = false;
  String? _lastPolledBackendStatus;

  // Backend has no automatic job that actually runs route optimization /
  // vehicle assignment for a ride — only a timer-driven status simulation.
  // So a real vehicle may never show up. Stop polling after this many
  // attempts (~2 min at 4s/poll) rather than polling forever.
  static const int _maxVehiclePollAttempts = 30;

  // Bounded reconnect for the tracking socket (no connection storms).
  static const int _maxTrackingReconnectAttempts = 5;

  // Status polling cadence while a ride is non-terminal.
  static const Duration _statusPollInterval = Duration(seconds: 5);

  String? get destination => _destination;
  GeoPoint? get destinationPoint => _destinationPoint;
  bool get isResolvingDestination => _isResolvingDestination;
  RideOption? get selectedOption => _selectedOption;
  GeoPoint? get pickupPoint => _pickupPoint;
  String get pickupLabel => _pickupLabel;
  bool get pickupConfirmed => _pickupConfirmed;
  bool get trafficEnabled => _trafficEnabled;
  RouteEstimate? get routeEstimate => _routeEstimate;
  bool get isLoadingRoute => _isLoadingRoute;

  /// The ride just booked, as the backend reports it (authoritative).
  RideRequestRecord? get activeRideRecord {
    final id = _currentRideId;
    if (id == null) return null;
    for (final ride in _myRides) {
      if (ride.id == id) return ride;
    }
    return null;
  }

  /// True while a booked ride has not reached a terminal state.
  bool get hasActiveRide => _currentRideId != null && !isRideTerminal;
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
    // Text only — coordinates are resolved by the backend geocoder in
    // confirmBooking() (the backend rejects non-India coordinates with 422).
    if (d != _destination) _destinationPoint = null;
    _destination = d;
    _error = null;
    _resetRoute();
    notifyListeners();
  }

  /// Adopt a geocoder suggestion for the destination (site `chooseSuggestion`).
  void setDestinationPoint(PlaceSuggestion place) {
    _destination = place.label;
    _destinationPoint = GeoPoint(place.lat, place.lng);
    _error = null;
    refreshRoute();
    notifyListeners();
  }

  /// Adopt a pickup: GPS fix, geocoder suggestion, or a point tapped on the
  /// map (already snapped to a road by the backend).
  void setPickup({
    required GeoPoint point,
    required String label,
  }) {
    _pickupPoint = point;
    _pickupLabel = label.trim().isEmpty ? 'Current location' : label.trim();
    _pickupConfirmed = true;
    _error = null;
    refreshRoute();
    notifyListeners();
  }

  /// Clears the pickup back to the backend's service default (site: typing in
  /// the pickup field invalidates the confirmed point).
  void clearPickup() {
    _pickupPoint = null;
    _pickupLabel = 'Current location';
    _pickupConfirmed = false;
    _resetRoute();
    notifyListeners();
  }

  void setTrafficEnabled(bool value) {
    if (_trafficEnabled == value) return;
    _trafficEnabled = value;
    refreshRoute();
    notifyListeners();
  }

  /// Pickup suggestions biased to the confirmed pickup when we have one
  /// (site: `geocodeApi.suggest(query, pickupPoint)`), otherwise to the
  /// default service point.
  Future<List<PlaceSuggestion>> suggestPlaces(String query) async {
    final bias = _pickupPoint ?? GeocodingService.defaultPickup;
    try {
      return await GeocodingService.suggest(query, bias: bias);
    } on ApiException {
      return const [];
    }
  }

  /// Resolves free text to one place (site: Enter / search button).
  Future<PlaceSuggestion?> searchPlace(String query) async {
    try {
      return await GeocodingService.resolve(query);
    } on ApiException {
      return null;
    }
  }

  // ── Route estimate (site: "Route estimate · 4.2 km · 12 min") ──────────

  /// Fetches the road route for the current pickup → destination pair.
  /// Best-effort: a failed lookup just means no ETA row, never an error
  /// state — the backend stays the authority on whether a ride is bookable.
  Future<void> refreshRoute() async {
    final destination = _destinationPoint;
    if (destination == null) {
      _resetRoute();
      return;
    }
    final pickup = _pickupPoint ?? GeocodingService.defaultPickup;
    final key =
        '${pickup.lat},${pickup.lng}:${destination.lat},${destination.lng}:$_trafficEnabled';
    if (key == _routeKey && _routeEstimate != null) return;
    _routeKey = key;
    _isLoadingRoute = true;
    notifyListeners();
    final estimate = await RoutingService.route(
      from: pickup,
      to: destination,
      traffic: _trafficEnabled,
    );
    // Ignore a stale response (the user changed something while we waited).
    if (key != _routeKey) return;
    _routeEstimate = estimate;
    _isLoadingRoute = false;
    notifyListeners();
  }

  void _resetRoute() {
    _routeEstimate = null;
    _routeKey = '';
    _isLoadingRoute = false;
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

  /// Applies one ride-status transition from the backend (WebSocket
  /// notification payload). [rideId] identifies which ride changed — the
  /// backend sends one notification per status change for ANY of the user's
  /// rides, so an event for another (e.g. older) ride must not leak into the
  /// active one. The ride record the UI reads is updated too, so every
  /// screen re-renders from the same authoritative status immediately —
  /// not just after the next poll (website parity: the site's 4 s poll sets
  /// `activeRide` directly).
  void handleRideStatusUpdate(String newStatus, int? rideId) {
    final tracked = _currentRideId;
    if (rideId != null && tracked != null && rideId != tracked) {
      return; // Another ride's transition — the active ride is unaffected.
    }
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
    _lastPolledBackendStatus = newStatus;
    _applyStatusToRideRecord(newStatus);
    // Keep the poll running while a ride is active: the WS is a hint, the
    // poll is the recovery path (e.g. socket dropped mid-ride).
    if (_currentRideId != null && !isRideTerminal) {
      _startStatusPolling();
    } else {
      _stopStatusPolling();
    }
    notifyListeners();
  }

  /// Rewrites the active ride's status in [_myRides] so the UI (which reads
  /// [activeRideRecord]) reflects the transition without a network round-trip.
  @visibleForTesting
  void debugSetRides(List<RideRequestRecord> rides, {int? currentRideId}) {
    _myRides
      ..clear()
      ..addAll(rides);
    if (currentRideId != null) _currentRideId = currentRideId;
  }

  /// Test seam for the post-[loadMyRides] restore step.
  @visibleForTesting
  void restoreFromRidesForTest() => _adoptRestorableRide();

  void _applyStatusToRideRecord(String newStatus) {
    final id = _currentRideId;
    if (id == null) return;
    final index = _myRides.indexWhere((r) => r.id == id);
    if (index == -1) return;
    if (_myRides[index].status == newStatus) return;
    _myRides[index] = _myRides[index].copyWithStatus(newStatus);
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

    final pickup = _pickupPoint ?? GeocodingService.defaultPickup;
    final pickupLabel = _pickupConfirmed ? _pickupLabel : 'Current location';

    _isBooking = true;
    _isResolvingDestination = true;
    _error = null;
    _stage = BookingStage.matching;
    _assignedVehicle = null;
    _vehiclePollAttempts = 0;
    _vehicleAssignmentTimedOut = false;
    _isFetchingVehicle = false;
    _stopVehicleTracking();
    notifyListeners();

    try {
      // Resolve the destination text to coordinates through the backend's
      // geocoder (Stadia-backed, India-only). Coordinates must come from the
      // same authority that validates them, otherwise bookings get rejected
      // with 422 outside-India errors.
      var destinationPoint = _destinationPoint;
      if (destinationPoint == null) {
        final resolved = await GeocodingService.resolve(_destination!);
        if (resolved == null) {
          _error =
              'Could not find "${_destination!}". Try a nearby landmark.';
          return false;
        }
        destinationPoint = GeoPoint(resolved.lat, resolved.lng);
        _destinationPoint = destinationPoint;
      }
      if (!destinationPoint.isInIndiaServiceArea) {
        // The backend would 422 this — fail fast with a clear message.
        _error = 'Destination is outside the supported India service area.';
        return false;
      }

      // Site order: resolve the road route first, then create the ride, so
      // the estimate shown in the panel matches the booked trip.
      final route = await RoutingService.route(
        from: pickup,
        to: destinationPoint,
        traffic: _trafficEnabled,
      );
      if (route != null) _routeEstimate = route;

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
          'pickup_label': pickupLabel,
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
      _startStatusPolling();
      await loadMyRides(silent: true);
      return true;
    } catch (error) {
      _error = _messageForException(error);
      notifyListeners();
      return false;
    } finally {
      _isBooking = false;
      _isResolvingDestination = false;
      notifyListeners();
    }
  }

  /// Cancels the ride just booked (site `handleCancel` → DELETE /rides/{id}).
  /// Only the backend decides whether a ride is still cancellable.
  Future<bool> cancelActiveRide() async {
    final rideId = _currentRideId;
    if (rideId == null) return false;
    try {
      await _api.deleteJson('/rides/$rideId');
      _stage = BookingStage.cancelled;
      _stopVehicleTracking(keepAttempts: true);
      _stopStatusPolling();
      notifyListeners();
      await loadMyRides(silent: true);
      return true;
    } catch (error) {
      _error = _messageForException(error);
      notifyListeners();
      return false;
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
      // Website parity: the site restores any in-flight ride on load. If a
      // non-terminal ride exists but isn't the tracked one (fresh app start,
      // or the tracked ride went terminal), adopt the newest non-terminal
      // one and resume its pollers so status updates keep flowing.
      _adoptRestorableRide();
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

  /// Website parity: `PassengerView` re-activates an in-flight ride from
  /// history. After a fresh app start (nothing tracked yet) the newest
  /// non-terminal ride from the last 24 h is adopted and its pollers resume,
  /// so status updates keep flowing. Older abandoned rides are left alone —
  /// the site likewise never auto-revives stale requests.
  void _adoptRestorableRide() {
    if (_currentRideId != null) return;
    RideRequestRecord? candidate;
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    for (final ride in _myRides) {
      if (RideStages.isTerminal(ride.status)) continue;
      if (ride.requestTime != null && ride.requestTime!.isBefore(cutoff)) {
        continue;
      }
      if (candidate == null || ride.id > candidate.id) candidate = ride;
    }
    if (candidate == null) return;

    _currentRideId = candidate.id;
    _stage = _stageForStatus(candidate.status) ?? BookingStage.matching;
    _lastPolledBackendStatus = candidate.status;
    _vehiclePollAttempts = 0;
    _vehicleAssignmentTimedOut = false;
    _isFetchingVehicle = false;
    _trackingReconnectAttempts = 0;
    _startStatusPolling();
    _startVehiclePolling();
  }

  void reset() {
    RazorpayService.reset();
    _paymentPhase = PaymentPhase.idle;
    _paymentError = null;
    _destination = null;
    _destinationPoint = null;
    _isResolvingDestination = false;
    _selectedOption = null;
    _stage = BookingStage.matching;
    _error = null;
    _currentRideId = null;
    _assignedVehicle = null;
    _vehiclePollAttempts = 0;
    _vehicleAssignmentTimedOut = false;
    _isFetchingVehicle = false;
    _lastPolledBackendStatus = null;
    _resetRoute();
    _stopVehicleTracking();
    _stopStatusPolling();
    notifyListeners();
  }

  /// "Dismiss · Book new ride" (site) — drops the finished ride from the panel
  /// without touching trip history.
  void dismissActiveRide() {
    _currentRideId = null;
    _assignedVehicle = null;
    _vehiclePollAttempts = 0;
    _vehicleAssignmentTimedOut = false;
    _isFetchingVehicle = false;
    _lastPolledBackendStatus = null;
    _stage = BookingStage.matching;
    if (_destinationPoint == null) _resetRoute();
    _stopVehicleTracking();
    _stopStatusPolling();
    notifyListeners();
  }

  /// Clears ride-booking state without touching destination history —
  /// used on logout to avoid leaking one account's trip into the next.
  void clearForLogout() {
    reset();
    _myRides.clear();
    RazorpayService.reset();
    _paymentPhase = PaymentPhase.idle;
    _paymentError = null;
  }

  // ── Status polling fallback ─────────────────────────────────────────────
  // The backend delivers ride-status changes ONLY as WebSocket notifications.
  // If the notifications socket is disconnected (its reconnect caps at 3
  // attempts), the stage machine would freeze forever on "Finding your
  // driver". This poll re-reads the authoritative status from the backend,
  // and also restarts vehicle polling if a vehicle was assigned in the
  // meantime (routes are optimized by backend jobs at any time).

  void _startStatusPolling() {
    _stopStatusPolling();
    _statusPollTimer = Timer.periodic(_statusPollInterval, (_) async {
      if (_isPollingStatus || _currentRideId == null) return;
      if (isRideTerminal) {
        _stopStatusPolling();
        return;
      }
      _isPollingStatus = true;
      try {
        final response =
            await _api.getJson('/rides/$_currentRideId');
        if (response is Map<String, dynamic>) {
          final backendStatus = (response['status'] ?? '').toString();
          final statusChanged = backendStatus != _lastPolledBackendStatus;
          _lastPolledBackendStatus = backendStatus;
          final stageFor = _stageForStatus(backendStatus);
          if (stageFor != null && stageFor != _stage) {
            // Advance the stage machine from authoritative server state.
            _stage = stageFor;
            if (isRideTerminal) _stopVehicleTracking(keepAttempts: true);
          }
          if (statusChanged) {
            // The UI reads the ride record, not this private stage — write
            // the authoritative status through (site: setActiveRide(r)).
            // The WS path notifies at the end of handleRideStatusUpdate; the
            // poll has no other notify, so it must notify here or the work
            // is invisible to the UI until something else rebuilds.
            _applyStatusToRideRecord(backendStatus);
            notifyListeners();
          }
          // A vehicle may appear while we poll (backend jobs assign routes
          // asynchronously). If the dedicated vehicle poller had given up,
          // give it ONE fresh burst of attempts per status transition —
          // restarting every tick would make the UI flicker between
          // "Assigning…" and "Not available" forever.
          if (statusChanged &&
              !isRideTerminal &&
              _assignedVehicle == null &&
              _vehiclePollTimer == null) {
            _startVehiclePolling();
          }
        }
      } on ApiException catch (e) {
        if (e.statusCode == 404 || e.statusCode == 403) {
          // Ride gone or not ours — stop polling; UI stays on current stage.
          _stopStatusPolling();
        }
        // Transient network/5xx: keep polling silently.
      } catch (_) {
        // Ignore one-off failures; the next tick retries.
      } finally {
        _isPollingStatus = false;
      }
    });
  }

  static BookingStage? _stageForStatus(String status) {
    switch (status) {
      case 'assigned':
        return BookingStage.found;
      case 'arriving':
      case 'in_progress':
        return BookingStage.arriving;
      case 'completed':
        return BookingStage.completed;
      case 'cancelled':
        return BookingStage.cancelled;
      default:
        return null; // pending/clustered keep the matching stage
    }
  }

  void _stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _isPollingStatus = false;
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
    // Backend contract: once a DRIVER manually assigns a ride,
    // PATCH /rides/{id}/status unlinks virtual_stop_id, so
    // GET /rides/{id}/vehicle stays null forever. Keep polling only while
    // the ride is still pre-assignment (pending/clustered — the auto-dispatch
    // pipeline path); afterwards a null is final, not a retry signal.
    if (_stage != BookingStage.matching) {
      _vehiclePollTimer?.cancel();
      _vehiclePollTimer = null;
      return;
    }
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
    if (_trackingChannel != null || _disposed) return;
    final vehicle = _assignedVehicle;
    if (vehicle == null) return;

    unawaited(() async {
      final token = await _api.liveToken();
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
          _trackingReconnectAttempts = 0;
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
        onError: (_) => _scheduleTrackingReconnect(),
        onDone: () => _scheduleTrackingReconnect(),
        cancelOnError: false,
      );
    }());
  }

  /// Bounded reconnect for the tracking socket: linear backoff (2s, 4s, 6s,
  /// 8s, 10s), capped at [_maxTrackingReconnectAttempts] so a dead backend
  /// can never cause a connection storm. Stops immediately for terminal
  /// rides or a null token (logged out).
  void _scheduleTrackingReconnect() {
    _teardownTrackingChannel();
    if (_disposed || isRideTerminal) return;
    if (_trackingReconnectAttempts >= _maxTrackingReconnectAttempts) return;
    _trackingReconnectAttempts++;
    _trackingReconnectTimer?.cancel();
    _trackingReconnectTimer = Timer(
      Duration(seconds: 2 * _trackingReconnectAttempts),
      () {
        if (_disposed || isRideTerminal) return;
        unawaited(() async {
          final token = await _api.liveToken();
          if (token == null || token.isEmpty) return;
          _connectVehicleTracking();
        }());
      },
    );
  }

  /// Closes the socket + subscription without touching reconnect state.
  void _teardownTrackingChannel() {
    _trackingReconnectTimer?.cancel();
    _trackingReconnectTimer = null;
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    try {
      _trackingChannel?.sink.close();
    } catch (_) {
      // Socket may already be closed.
    }
    _trackingChannel = null;
  }

  void _stopVehicleTracking({bool keepAttempts = false}) {
    _vehiclePollTimer?.cancel();
    _vehiclePollTimer = null;
    if (!keepAttempts) _vehiclePollAttempts = 0;
    _isFetchingVehicle = false;
    _teardownTrackingChannel();
    if (!keepAttempts) _trackingReconnectAttempts = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopVehicleTracking();
    _stopStatusPolling();
    super.dispose();
  }
}
