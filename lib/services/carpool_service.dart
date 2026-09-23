import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Carpool lifecycle calls: the passenger's pickup confirmation and the
/// driver's Carpool Run actions.
///
/// Every method hits the backend's carpool endpoints — the client keeps no
/// carpool state of its own, so a run can only advance through the server's
/// own guards (a passenger may not board before the driver confirms, a run
/// completes only after every rider is dropped off, and so on). Failures
/// surface as [ApiException]; callers must not retry blindly.
class CarpoolService {
  CarpoolService._([ApiClient? api]) : _api = api ?? ApiClient.instance;

  static final CarpoolService instance = CarpoolService._();

  /// An isolated service over a caller-supplied client, so the endpoints can
  /// be exercised without a live backend.
  @visibleForTesting
  factory CarpoolService.withClient(ApiClient api) => CarpoolService._(api);

  final ApiClient _api;

  /// Passenger confirms they reached the assigned pickup stop.
  /// `POST /rides/{id}/confirm-pickup`.
  Future<void> confirmAtPickupStop(int rideId) async {
    await _api.postJson('/rides/$rideId/confirm-pickup');
  }

  /// Driver accepts the carpool run: `POST /route/{id}/accept`.
  Future<void> acceptRoute(String routeId) async {
    await _api.postJson('/route/$routeId/accept');
  }

  /// Driver starts heading to one rider's pickup stop.
  /// `POST /route/{id}/carpool/announce-pickup/{rideId}`.
  Future<void> announcePickup(String routeId, int rideId) async {
    await _api.postJson('/route/$routeId/carpool/announce-pickup/$rideId');
  }

  /// Driver reached the pickup stop: `POST /route/{id}/carpool/mark-arrived/{rideId}`.
  Future<void> markArrived(String routeId, int rideId) async {
    await _api.postJson('/route/$routeId/carpool/mark-arrived/$rideId');
  }

  /// Driver confirmed the passenger boarded:
  /// `POST /route/{id}/carpool/confirm-pickup/{rideId}`.
  Future<void> confirmBoarded(String routeId, int rideId) async {
    await _api.postJson('/route/$routeId/carpool/confirm-pickup/$rideId');
  }

  /// Driver starts driving: every boarded rider moves to IN_TRANSIT.
  /// `POST /route/{id}/carpool/depart`.
  Future<void> depart(String routeId) async {
    await _api.postJson('/route/$routeId/carpool/depart');
  }

  /// Driver confirmed one rider was dropped off:
  /// `POST /route/{id}/carpool/confirm-dropoff/{rideId}`.
  Future<void> confirmDropoff(String routeId, int rideId) async {
    await _api.postJson('/route/$routeId/carpool/confirm-dropoff/$rideId');
  }

  /// Driver confirms the final drop-off. The backend refuses unless every
  /// rider is already dropped off: `POST /route/{id}/carpool/complete`.
  Future<void> completeRoute(String routeId) async {
    await _api.postJson('/route/$routeId/carpool/complete');
  }
}
