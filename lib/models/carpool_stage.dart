import 'shared_route.dart';

/// The passenger-facing carpool lifecycle.
///
/// The backend owns the authoritative per-rider stage (`ride_requests`
/// `carpool_status`, see backend `utils/carpool_status.py`). This enum maps its
/// wire string to an ordered stage so every screen renders the same progress
/// for the same ride — the client never invents carpool state.
enum CarpoolStage {
  pending('pending', 'Searching'),
  searching('searching', 'Searching for riders'),
  clustered('clustered', 'Riders matched'),
  assigned('assigned', 'Driver assigned'),
  driverAccepted('driver_accepted', 'Driver accepted'),
  driverArriving('driver_arriving', 'Driver arriving'),
  pickupReady('pickup_ready', 'Driver at your stop'),
  passengerConfirmed('passenger_confirmed_pickup_stop', 'You are at the stop'),
  boarded('boarded', 'Onboard'),
  inTransit('in_transit', 'In transit'),
  droppedOff('dropped_off', 'Dropped off'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const CarpoolStage(this.wire, this.label);

  /// The backend `carpool_status` string.
  final String wire;

  /// Human label for progress UI.
  final String label;

  /// A finished ride: no further carpool progress is expected.
  bool get isTerminal =>
      this == CarpoolStage.completed || this == CarpoolStage.cancelled;

  /// The backend only refuses cancellation once a ride is `in_progress` or
  /// `completed`; every stage before boarding is still cancellable.
  bool get isCancellable =>
      !isTerminal && index < CarpoolStage.boarded.index;

  /// The driver is at (or approaching) the assigned stop, so the passenger can
  /// confirm they have reached it (`POST /rides/{id}/confirm-pickup`).
  bool get canConfirmPickupStop =>
      this == CarpoolStage.driverArriving || this == CarpoolStage.pickupReady;

  /// Parse the backend stage, or null when absent/unknown.
  static CarpoolStage? fromWire(String? wire) {
    if (wire == null) return null;
    final key = wire.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final stage in CarpoolStage.values) {
      if (stage.wire == key) return stage;
    }
    return null;
  }

  /// Best-effort stage for a ride, preferring the authoritative
  /// `carpool_status` and falling back to the coarse status plus what the
  /// pooled route reveals (older rows written before `carpool_status` existed).
  static CarpoolStage fromRide({
    required String status,
    String? carpoolStatus,
    SharedRoute? route,
  }) {
    final direct = fromWire(carpoolStatus);
    if (direct != null) return direct;
    switch (status.toLowerCase()) {
      case 'clustered':
        return CarpoolStage.clustered;
      case 'assigned':
        return (route?.driverAccepted ?? false)
            ? CarpoolStage.driverAccepted
            : CarpoolStage.assigned;
      case 'arriving':
        return CarpoolStage.driverArriving;
      case 'ready_for_pickup':
        return CarpoolStage.passengerConfirmed;
      case 'in_progress':
        return CarpoolStage.inTransit;
      case 'completed':
        return CarpoolStage.droppedOff;
      case 'cancelled':
        return CarpoolStage.cancelled;
      default:
        return CarpoolStage.pending;
    }
  }
}
