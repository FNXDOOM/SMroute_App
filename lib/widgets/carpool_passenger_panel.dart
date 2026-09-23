import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/carpool_stage.dart';
import '../providers/ride_provider.dart';
import '../theme/app_theme.dart';
import 'carpool_stage_stepper.dart';
import 'carpool_stop_list.dart';
import 'ui_kit.dart';

/// The passenger's carpool panel: where the ride sits in the carpool lifecycle,
/// the assigned pickup stop with its walking distance, and the confirm action.
///
/// Renders nothing for a private ride — the normal ride panel already covers it.
class CarpoolPassengerPanel extends StatelessWidget {
  const CarpoolPassengerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    final stage = provider.carpoolStage;
    if (stage == null) return const SizedBox.shrink();

    final stop = provider.myPickupStop;
    final route = provider.sharedRoute;
    final pickupStops =
        route?.stops.where((s) => s.isPickup).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(eyebrow: 'Carpool', title: 'Your carpool ride'),
        const SizedBox(height: AppSpacing.sm),
        CarpoolStageStepper(stage: stage),
        if (stop != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Your pickup stop'),
                const SizedBox(height: AppSpacing.xs),
                InfoRow(
                  icon: Icons.directions_walk,
                  label: 'Walk to the assigned stop',
                  value: provider.pickupWalkMeters == null
                      ? '${stop.point.lat.toStringAsFixed(4)}, '
                          '${stop.point.lng.toStringAsFixed(4)}'
                      : _metres(provider.pickupWalkMeters!),
                ),
                const SizedBox(height: AppSpacing.xxs),
                InfoRow(
                  icon: Icons.people_alt_outlined,
                  label: 'Riders on this carpool',
                  value: pickupStops == 1
                      ? '1 pickup stop'
                      : '$pickupStops pickup stops',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: _confirmLabel(stage),
            icon: Icons.check_circle_outline,
            loading: provider.isConfirmingPickupStop,
            onPressed:
                provider.canConfirmPickupStop && !provider.isConfirmingPickupStop
                    ? () => _confirm(context, provider)
                    : null,
          ),
        ],
        if (route != null && route.stops.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const SectionLabel('Stops on your route'),
          const SizedBox(height: AppSpacing.xs),
          CarpoolStopList(
            rows: [
              for (final stop in route.stops)
                CarpoolStopRow(
                  sequence: stop.sequence,
                  waypointType: stop.waypointType,
                  // Other riders stay private on the passenger view.
                  riders: const [],
                  walkMeters: stop.isMine && stop.isPickup ? stop.walkMeters : null,
                ),
            ],
            emptyHint: 'The pooled stops appear once your route is optimized.',
          ),
        ],
      ],
    );
  }

  static String _confirmLabel(CarpoolStage stage) {
    if (stage.index >= CarpoolStage.passengerConfirmed.index) {
      return 'Pickup stop confirmed';
    }
    if (stage.canConfirmPickupStop) return "I'm at the pickup stop";
    return 'Confirm when you reach the stop';
  }

  Future<void> _confirm(BuildContext context, RideProvider provider) async {
    final ok = await provider.confirmAtPickupStop();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? "You're at the pickup stop"
                : (provider.error ?? 'Could not confirm your arrival'),
          ),
        ),
      );
  }

  static String _metres(double metres) {
    if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km';
    return '${(metres / 10).round() * 10} m';
  }
}
