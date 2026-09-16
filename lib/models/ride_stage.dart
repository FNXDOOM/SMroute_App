/// The website's ride lifecycle, in order
/// (frontend/src/views/PassengerView.jsx `RIDE_STAGES` / `RIDE_STAGE_LABELS`).
/// The backend owns the status string; this maps it to a 0-based step so every
/// screen renders the same progress for the same ride.
class RideStages {
  RideStages._();

  static const List<String> keys = [
    'pending',
    'clustered',
    'assigned',
    'arriving',
    'in_progress',
    'completed',
  ];

  static const List<String> labels = [
    'Requested',
    'Clustered',
    'Assigned',
    'Arriving',
    'In transit',
    'Delivered',
  ];

  /// Step index for a backend status, clamped to the known range so an
  /// unexpected status can never crash the stepper.
  static int indexOf(String? status) {
    final key = (status ?? '').toLowerCase();
    final index = keys.indexOf(key);
    if (index != -1) return index;
    // Cancelled rides never reach "delivered"; keep them at the start.
    if (key == 'cancelled' || key == 'canceled') return 0;
    return 0;
  }

  /// Human label for a backend status (site: `RIDE_STAGE_LABELS[status]`).
  static String labelOf(String? status) {
    final key = (status ?? '').toLowerCase();
    final index = keys.indexOf(key);
    if (index != -1) return labels[index];
    if (key.isEmpty) return 'Requested';
    final spaced = key.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Terminal states stop polling and switch the panel to its receipt view.
  static bool isTerminal(String? status) {
    final key = (status ?? '').toLowerCase();
    return key == 'completed' || key == 'cancelled' || key == 'canceled';
  }

  /// The site only offers cancellation while a ride is still unassigned.
  static bool isCancellable(String? status) {
    final key = (status ?? '').toLowerCase();
    return key == 'pending' || key == 'clustered';
  }
}
