import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/carpool_stage.dart';
import '../../models/ride_request_record.dart';
import '../../models/shared_route.dart';
import '../../models/vehicle_animation.dart' show distanceMeters;
import '../../providers/driver_provider.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/carpool_stop_list.dart';
import '../../widgets/live_map.dart';
import '../../widgets/ui_kit.dart';

/// Dedicated Carpool Run screen.
///
/// All carpool riding happens here, never on the normal dispatch board: the run
/// is driven stop by stop through the backend's carpool endpoints (accept,
/// announce, arrived, board, depart, drop-off, complete). Every action is
/// guarded server-side, so this screen only offers the step the backend will
/// accept next.
class CarpoolRunScreen extends StatefulWidget {
  const CarpoolRunScreen({super.key});

  @override
  State<CarpoolRunScreen> createState() => _CarpoolRunScreenState();
}

class _CarpoolRunScreenState extends State<CarpoolRunScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The console that pushed this screen owns the poll lifecycle, so this
      // only kicks the board; it never stops polling on dispose.
      context.read<DriverProvider>().load();
    });
  }

  Future<void> _run(Future<bool> Function() action, String success) async {
    final provider = context.read<DriverProvider>();
    final ok = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? success : (provider.error ?? 'Update failed')),
        ),
      );
  }

  /// The rider to serve next, in route order (pickups before drop-offs).
  RideRequestRecord? _nextRider(DriverProvider provider) {
    final route = provider.assignedRoute;
    final rides = provider.carpoolRides;
    if (route == null || rides.isEmpty) return null;

    final sequenceByRide = <int, int>{};
    for (final stop in route.stops) {
      if (!stop.isPickup) continue;
      for (final rideId in stop.passengerIds) {
        sequenceByRide.putIfAbsent(rideId, () => stop.sequence);
      }
    }
    final ordered = [...rides]..sort((a, b) => (sequenceByRide[a.id] ?? 1 << 30)
        .compareTo(sequenceByRide[b.id] ?? 1 << 30));

    for (final ride in ordered) {
      final stage = provider.carpoolStageFor(ride);
      const done = {
        CarpoolStage.droppedOff,
        CarpoolStage.completed,
        CarpoolStage.cancelled,
      };
      if (!done.contains(stage)) return ride;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final route = provider.assignedRoute;
    final vehicle = provider.myVehicle;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.paper,
          backgroundColor: AppColors.surface,
          onRefresh: provider.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            children: [
              PageHeader(
                title: 'Carpool run',
                description: vehicle == null
                    ? 'No vehicle selected'
                    : '${vehicle.licensePlate} · ${vehicle.status}',
                onBack: () => Navigator.maybePop(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (route == null || !provider.hasCarpoolRun)
                const EmptyState(
                  icon: Icons.alt_route,
                  title: 'No carpool run assigned',
                  hint: 'Go on duty and share your position so dispatch can '
                      'assign a pooled route to your vehicle.',
                )
              else ...[
                _runHeader(provider, route),
                if (!provider.carpoolAccepted) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Accept run',
                    icon: Icons.check_circle_outline,
                    loading: provider.isBusy,
                    onPressed: provider.isBusy
                        ? null
                        : () => _run(
                              provider.acceptCarpoolRun,
                              'Carpool run accepted',
                            ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                LiveMap(
                  height: 240,
                  cameraPadding: const EdgeInsets.all(32),
                  route: route.geometry,
                  routeSegments: route.legPoints,
                  segmentsMode:
                      provider.routeDisplay == RouteDisplayMode.segments,
                  routeStops: route.stops,
                  nextStopSequence: provider.nextStop?.stop.sequence,
                  onToggleSegments: provider.hasSegmentedRoute
                      ? provider.toggleRouteDisplay
                      : null,
                  vehicles: [
                    if (provider.vehiclePoint != null)
                      MapVehicle(
                        id: '${vehicle?.id ?? 'me'}',
                        lat: provider.vehiclePoint!.lat,
                        lng: provider.vehiclePoint!.lng,
                        label: vehicle?.licensePlate ?? 'You',
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SheetHeader(
                  eyebrow: 'Itinerary',
                  title: 'Pickups and drop-offs',
                  subtitle: provider.nextStop == null
                      ? 'Every stop served'
                      : 'Next: ${_kind(provider.nextStop!.stop)} · '
                          '${provider.pendingStopCount} stop(s) to go',
                  trailing: StatusBadge(status: route.problem),
                ),
                if (provider.nextStop != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'ETA to next stop',
                    value: _eta(provider.nextStop!),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                CarpoolStopList(
                  rows: _rows(provider, route),
                  riderLabel: (id) => 'Rider #$id',
                  riderStatus: (id) => _stageLabel(provider, id),
                  emptyHint: 'Stops appear once this run is optimized.',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (provider.carpoolAccepted)
                  ..._actions(provider),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _runHeader(DriverProvider provider, SharedRoute route) {
    final accepted = provider.carpoolAccepted;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Route ${route.routeId}', style: AppType.smallStrong),
              ),
              StatusBadge(
                status: accepted
                    ? (route.carpoolRunStatus == 'completed' ? 'completed' : 'accepted')
                    : 'pending',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(
            icon: Icons.people_alt_outlined,
            label: 'Passengers',
            value:
                '${provider.carpoolRiderCount} / ${provider.carpoolCapacity} passengers',
          ),
          const SizedBox(height: AppSpacing.xxs),
          InfoRow(
            icon: Icons.drive_eta_outlined,
            label: 'Driver acceptance',
            value: accepted ? 'Accepted' : 'Waiting for you to accept',
          ),
          const SizedBox(height: AppSpacing.xxs),
          InfoRow(
            icon: Icons.route_outlined,
            label: 'Route status',
            value: '${route.problem.toUpperCase()} · ${route.routeStatus}',
          ),
        ],
      ),
    );
  }

  List<CarpoolStopRow> _rows(DriverProvider provider, SharedRoute route) {
    final nextSequence = provider.nextStop?.stop.sequence;
    final rideById = {for (final ride in provider.carpoolRides) ride.id: ride};
    return [
      for (final stop in route.stops)
        CarpoolStopRow(
          sequence: stop.sequence,
          waypointType: stop.waypointType,
          riders: stop.passengerIds,
          walkMeters: stop.isPickup ? _maxWalk(stop, rideById) : null,
          isNext: stop.sequence == nextSequence,
        ),
    ];
  }

  /// The longest walk any rider at this pickup must make, from their original
  /// pickup to the assigned stop. Straight line, matching the backend's own
  /// 150 m rule.
  static double? _maxWalk(
    RouteStop stop,
    Map<int, RideRequestRecord> rides,
  ) {
    double? worst;
    for (final rideId in stop.passengerIds) {
      final ride = rides[rideId];
      if (ride == null) continue;
      final metres = distanceMeters(
        GeoPoint(ride.pickupLat, ride.pickupLng),
        stop.point,
      );
      if (worst == null || metres > worst) worst = metres;
    }
    return worst;
  }

  List<Widget> _actions(DriverProvider provider) {
    final busy = provider.isBusy;
    final next = _nextRider(provider);
    final anyBoarded = provider.carpoolRides.any(
      (ride) => provider.carpoolStageFor(ride) == CarpoolStage.boarded,
    );
    final allDropped = provider.carpoolRides.isNotEmpty &&
        provider.carpoolRides.every((ride) {
          const done = {
            CarpoolStage.droppedOff,
            CarpoolStage.completed,
            CarpoolStage.cancelled,
          };
          return done.contains(provider.carpoolStageFor(ride));
        });
    final widgets = <Widget>[];

    if (next != null) {
      final stage = provider.carpoolStageFor(next);
      final (label, icon, action, success) = switch (stage) {
        CarpoolStage.assigned || CarpoolStage.driverAccepted => (
            'Start navigation',
            Icons.navigation_outlined,
            () => provider.announcePickup(next),
            'Notified rider #${next.id} you are on the way',
          ),
        CarpoolStage.driverArriving => (
            'Arrived at stop',
            Icons.place_outlined,
            () => provider.markArrived(next),
            'Rider #${next.id} told you have arrived',
          ),
        CarpoolStage.pickupReady => (
            'Waiting for rider to confirm',
            Icons.hourglass_empty,
            null,
            '',
          ),
        CarpoolStage.passengerConfirmed => (
            'Confirm passenger boarded',
            Icons.person_add_alt_1_outlined,
            () => provider.confirmBoarded(next),
            'Rider #${next.id} is onboard',
          ),
        CarpoolStage.boarded => (
            'Start driving',
            Icons.play_arrow,
            () => provider.departCarpoolRun(),
            'On the way',
          ),
        CarpoolStage.inTransit => (
            'Confirm passenger dropped off',
            Icons.person_remove_alt_1_outlined,
            () => provider.confirmDropoff(next),
            'Rider #${next.id} dropped off',
          ),
        _ => ('', null, null, ''),
      };

      if (label.isNotEmpty) {
        widgets.add(
          AppButton(
            label: label,
            icon: icon,
            loading: busy,
            onPressed: busy || action == null
                ? null
                : () => _run(action, success),
          ),
        );
      }
    }

    if (anyBoarded) {
      widgets.add(const SizedBox(height: AppSpacing.sm));
      widgets.add(
        AppButton(
          label: 'Start driving',
          icon: Icons.play_arrow,
          variant: AppButtonVariant.secondary,
          loading: busy,
          onPressed: busy
              ? null
              : () => _run(provider.departCarpoolRun, 'On the way'),
        ),
      );
    }

    widgets.add(const SizedBox(height: AppSpacing.sm));
    widgets.add(
      AppButton(
        label: 'Complete route',
        icon: Icons.flag_outlined,
        variant: AppButtonVariant.secondary,
        loading: busy,
        onPressed: busy || !allDropped
            ? null
            : () => _run(
                  provider.completeCarpoolRun,
                  'Carpool run completed',
                ),
      ),
    );
    if (!allDropped) {
      widgets.add(const SizedBox(height: AppSpacing.xs));
      widgets.add(
        Text(
          'Every rider must be dropped off before the run can be completed.',
          style: AppType.caption.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return widgets;
  }

  static String _kind(RouteStop stop) => switch (stop.waypointType) {
        'pickup' => 'Pickup ${stop.sequence + 1}',
        'destination' => 'Drop-off ${stop.sequence + 1}',
        _ => 'Stop ${stop.sequence + 1}',
      };

  /// The rider's carpool stage, for the stop row's rider status.
  static String _stageLabel(DriverProvider provider, int rideId) {
    for (final ride in provider.carpoolRides) {
      if (ride.id == rideId) return provider.carpoolStageFor(ride).label;
    }
    return 'Unknown';
  }

  /// Straight-line distance to the next stop with the route's own average
  /// speed, so the figure is an estimate until real navigation exists.
  static String _eta(RouteNextStop next) {
    final metres = next.distanceMeters;
    if (metres == null) return 'Waiting for your position';
    final distance = metres >= 1000
        ? '${(metres / 1000).toStringAsFixed(1)} km'
        : '${(metres / 10).round() * 10} m';
    final minutes = next.minutes;
    return minutes == null ? distance : '$distance · ~$minutes min';
  }
}
