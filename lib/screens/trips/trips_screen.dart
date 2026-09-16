import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ride_request_record.dart';
import '../../models/ride_stage.dart';
import '../../providers/ride_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Trips — the website's `TripsView` + `TripDetail`, on the app's flat list
/// language (hairline rows, no card per trip) with a detail sheet.
///
/// Every row is real: rides come from `GET /rides/my-rides` in the order the
/// backend returns them. Nothing is scheduled, simulated or invented — the
/// website has no scheduled-ride feature, so neither does the app.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RideProvider>().loadMyRides();
    });
  }

  Future<void> _refresh() => context.read<RideProvider>().loadMyRides();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    final rides = provider.myRides;
    final loading = provider.isLoadingRides && rides.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: PageHeader(
                title: 'Your trips',
                description: rides.isEmpty
                    ? 'Your ride history'
                    : '${rides.length} booking${rides.length == 1 ? '' : 's'}',
                onBack: () => Navigator.pushReplacementNamed(context, '/home'),
                backLabel: 'Home',
              ),
            ),
            Expanded(
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.gutter,
                      ),
                      child: SkeletonRows(count: 5, height: 72),
                    )
                  : RefreshIndicator(
                      color: AppColors.paper,
                      backgroundColor: AppColors.surface,
                      onRefresh: _refresh,
                      child: rides.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.gutter,
                                vertical: AppSpacing.sm,
                              ),
                              children: [
                                EmptyState(
                                  icon: Icons.trip_origin,
                                  title: 'No trips yet',
                                  hint:
                                      'Book your first ride from Home — it '
                                      'will show up here with live status.',
                                  action: AppButton(
                                    label: 'Book a ride',
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/home',
                                        ),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.gutter,
                                0,
                                AppSpacing.gutter,
                                AppSpacing.xl,
                              ),
                              children: [
                                for (final ride in rides)
                                  _TripRow(
                                    ride: ride,
                                    onTap: () => _openDetail(ride),
                                  ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(RideRequestRecord ride) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (sheetContext) => _TripDetailSheet(ride: ride),
    );
  }
}

/// One trip: id + status, the pickup → drop-off pair, tier and timestamp.
class _TripRow extends StatelessWidget {
  const _TripRow({required this.ride, required this.onTap});

  final RideRequestRecord ride;
  final VoidCallback onTap;

  static String _dateLabel(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    return '${local.day}/${local.month}/${local.year}, $time';
  }

  @override
  Widget build(BuildContext context) {
    return ListRow(
      onTap: onTap,
      title: 'Ride #${ride.id}',
      emphasised: !RideStages.isTerminal(ride.status),
      subtitle:
          '${ride.rideOptionName ?? 'Standard'} · '
          '${_dateLabel(ride.requestTime)}',
      leading: const PlaceMark(marker: PlaceMarker.square, size: 18),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(status: ride.status),
          const SizedBox(width: AppSpacing.xxs),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textSubtle,
          ),
        ],
      ),
    );
  }
}

/// Trip detail — the website's `TripDetail`: route pair, fare, H3 cell and the
/// assigned vehicle for the live ride, plus Cancel while the backend still
/// allows it.
class _TripDetailSheet extends StatelessWidget {
  const _TripDetailSheet({required this.ride});

  final RideRequestRecord ride;

  static String _fullDate(DateTime? t) =>
      t == null ? '—' : t.toLocal().toString().split('.').first;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    final isActiveRide = provider.currentRideId == ride.id;
    final vehicle = isActiveRide ? provider.assignedVehicle : null;

    return SheetPanel(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              eyebrow: 'Trip details',
              title: 'Ride #${ride.id}',
              subtitle: _fullDate(ride.requestTime),
              trailing: StatusBadge(status: ride.status),
            ),
            const SizedBox(height: AppSpacing.md),
            RouteLeg(
              pickup: ride.pickupLabel,
              destination: ride.destinationLabel,
            ),
            const SizedBox(height: AppSpacing.md),
            InfoRow(
              label: 'Ride tier',
              value: ride.rideOptionName ?? 'Standard',
            ),
            if (ride.rideOptionPrice != null) ...[
              const SizedBox(height: AppSpacing.xs),
              InfoRow(label: 'Fare', value: ride.rideOptionPrice!),
            ],
            if (ride.h3Index != null) ...[
              const SizedBox(height: AppSpacing.xs),
              InfoRow(label: 'H3 cell', value: ride.h3Index!),
            ],
            if (ride.clusterId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              InfoRow(label: 'Cluster', value: '${ride.clusterId}'),
            ],
            if (vehicle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              InfoRow(label: 'Vehicle', value: vehicle.licensePlate),
              const SizedBox(height: AppSpacing.xs),
              InfoRow(label: 'Vehicle status', value: vehicle.status),
              if (vehicle.lat != null && vehicle.lng != null) ...[
                const SizedBox(height: AppSpacing.xs),
                InfoRow(
                  label: 'Position',
                  value:
                      '${vehicle.lat!.toStringAsFixed(4)}, '
                      '${vehicle.lng!.toStringAsFixed(4)}',
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            if (isActiveRide && !RideStages.isTerminal(ride.status))
              AppButton(
                label: 'Track live',
                icon: Icons.navigation_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/ride-confirm');
                },
              )
            else
              AppButton(
                label: 'Close',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            if (RideStages.isCancellable(ride.status) && isActiveRide) ...[
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Cancel ride',
                variant: AppButtonVariant.secondary,
                destructive: true,
                onPressed: () async {
                  final confirmed = await showAppConfirm(
                    context,
                    title: 'Cancel this ride?',
                    message: 'Your driver assignment will be released.',
                    confirmLabel: 'Cancel ride',
                    destructive: true,
                  );
                  if (!confirmed || !context.mounted) return;
                  final ok = await provider.cancelActiveRide();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Ride cancelled'
                            : (provider.error ?? 'Cannot cancel this ride'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
