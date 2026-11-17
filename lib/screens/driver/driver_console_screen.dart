import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ride_request_record.dart';
import '../../models/shared_route.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/live_map.dart';
import '../../widgets/ui_kit.dart';

/// Driver console — the website's DriverView, translated to mobile:
/// vehicle picker + duty toggle + GPS push on top, dispatch board (pending →
/// accept → arriving → in_progress → completed) below. All data and actions
/// hit the same endpoints the website's DriverView uses.
class DriverConsoleScreen extends StatefulWidget {
  const DriverConsoleScreen({super.key});

  @override
  State<DriverConsoleScreen> createState() => _DriverConsoleScreenState();
}

class _DriverConsoleScreenState extends State<DriverConsoleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<DriverProvider>();
      // Website parity (DriverView.refreshRides): toast new incoming
      // requests as the polled board reveals them.
      provider.onNewPendingRide = (ride) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'New ride request #${ride.id} · '
                '${ride.pickupLabel} → ${ride.destinationLabel}',
              ),
            ),
          );
      };
      provider.load();
    });
  }

  @override
  void dispose() {
    // App-scoped provider: stop the board poll and drop the callback that
    // references this screen's context.
    context.read<DriverProvider>().stopBoardPolling();
    super.dispose();
  }

  Future<void> _pushLocation() async {
    final provider = context.read<DriverProvider>();
    final ok = await provider.pushMyLocation();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Position shared with dispatch'
                : (provider.error ?? 'Could not get a GPS fix'),
          ),
        ),
      );
  }

  Future<void> _toggleDuty() async {
    final provider = context.read<DriverProvider>();
    final vehicle = provider.myVehicle;
    if (vehicle == null) return;
    final goingOnDuty = vehicle.status != 'active';
    final ok = await provider.setDuty(goingOnDuty);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            goingOnDuty
                ? (ok ? "You're on duty" : (provider.error ?? 'Update failed'))
                : (ok
                      ? "You're off duty"
                      : (provider.error ?? 'Update failed')),
          ),
        ),
      );
  }

  Future<void> _accept(RideRequestRecord ride) async {
    final provider = context.read<DriverProvider>();
    final ok = await provider.acceptRide(ride);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Ride #${ride.id} accepted'
                : (provider.error ?? 'Could not accept ride'),
          ),
        ),
      );
  }

  Future<void> _advance(RideRequestRecord ride, String next) async {
    final labels = {
      'arriving': 'Mark arriving',
      'in_progress': 'Start trip',
      'completed': 'Complete trip',
    };
    final provider = context.read<DriverProvider>();
    final ok = await provider.advanceRide(ride, next);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Ride #${ride.id} · ${labels[next] ?? next}'
                : (provider.error ?? 'Update failed'),
          ),
        ),
      );
  }

  void _openVehiclePicker() {
    final provider = context.read<DriverProvider>();
    if (provider.vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicles registered yet')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SheetHeader(
                eyebrow: 'Dispatch',
                title: 'Choose your vehicle',
              ),
            ),
            for (final v in provider.vehicles)
              ListRow(
                title: v.licensePlate,
                subtitle: 'Capacity ${v.capacity} · ${v.status}',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<DriverProvider>().selectVehicle(v);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final vehicle = provider.myVehicle;
    final onDuty = vehicle?.status == 'active';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.paper,
          backgroundColor: AppColors.surface,
          onRefresh: () => provider.load(),
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
                title: 'Driver console',
                description: () {
                  final name = context
                      .read<AuthProvider>()
                      .currentUser
                      ?.firstName;
                  return name == null ? 'Dispatch board' : 'Welcome, $name';
                }(),
                onBack: () => Navigator.maybePop(context),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Vehicle + duty ──────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('My vehicle'),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle?.licensePlate ?? 'No vehicle selected',
                            style: AppType.data.copyWith(fontSize: 18),
                          ),
                        ),
                        IconSquareButton(
                          icon: Icons.swap_horiz,
                          tooltip: 'Change vehicle',
                          onTap: _openVehiclePicker,
                        ),
                      ],
                    ),
                    if (vehicle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Capacity ${vehicle.capacity} · ${vehicle.status}',
                        style: AppType.small.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: onDuty ? 'Go off duty' : 'Go on duty',
                            variant: onDuty
                                ? AppButtonVariant.secondary
                                : AppButtonVariant.primary,
                            loading: provider.isBusy,
                            onPressed: vehicle == null ? null : _toggleDuty,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconSquareButton(
                          icon: Icons.my_location,
                          tooltip: 'Update my position',
                          onTap: provider.isUpdatingLocation
                              ? null
                              : _pushLocation,
                        ),
                      ],
                    ),
                    if (provider.isUpdatingLocation) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Carpool run entry ────────────────────────────────────────
              // Carpool riding lives on its own screen; the dashboard below
              // carries normal (private) rides only.
              if (provider.hasCarpoolRun) ...[
                _CarpoolRunEntry(provider: provider),
                const SizedBox(height: AppSpacing.xl),
              ] else if (provider.assignedRoute != null) ...[
                // A private ride's pooled route, drawn for context.
                _AssignedRoutePanel(provider: provider),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Dispatch board ───────────────────────────────────────────
              SheetHeader(
                eyebrow: 'Dispatch board',
                title: 'Rides to run',
                trailing: StatusBadge(status: onDuty ? 'active' : 'idle'),
              ),
              const SizedBox(height: AppSpacing.sm),

              if (provider.isLoading && provider.board.isEmpty)
                const SkeletonRows(count: 3, height: 84)
              else if (provider.error != null && provider.board.isEmpty) ...[
                ErrorBanner(message: provider.error!),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Retry',
                  variant: AppButtonVariant.secondary,
                  onPressed: provider.load,
                ),
              ] else ...[
                if (provider.normalActiveRides.isEmpty &&
                    provider.normalPendingRides.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No rides right now',
                    hint:
                        'New bookings appear here. Go on duty and share your '
                        'position so dispatch can route you.',
                  )
                else ...[
                  for (final ride in provider.normalActiveRides)
                    _DriverRideCard(
                      ride: ride,
                      busy: provider.isBusy,
                      onAdvance: () => _advance(ride, _nextStatus(ride.status)),
                      onAccept: null,
                    ),
                  for (final ride in provider.normalPendingRides)
                    _DriverRideCard(
                      ride: ride,
                      busy: provider.isBusy,
                      onAccept: () => _accept(ride),
                      onAdvance: null,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _nextStatus(String status) {
    switch (status) {
      case 'assigned':
        return 'arriving';
      case 'arriving':
        return 'in_progress';
      default:
        return 'completed';
    }
  }
}

/// The vehicle's pooled route: the optimized stop sequence as an interactive
/// map (whole line or leg by leg), then the stop to serve next.
class _AssignedRoutePanel extends StatelessWidget {
  const _AssignedRoutePanel({required this.provider});

  final DriverProvider provider;

  @override
  Widget build(BuildContext context) {
    final route = provider.assignedRoute!;
    final next = provider.nextStop;
    final vehicle = provider.myVehicle;
    final lat = vehicle?.lat;
    final lng = vehicle?.lng;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          eyebrow: 'Assigned route',
          title: 'Your pooled stops',
          subtitle:
              '${route.stops.length} stops · '
              '${(route.distanceMeters / 1000).toStringAsFixed(1)} km pooled',
          // The problem the solver ran: pdp pools pickups and drop-offs.
          trailing: StatusBadge(status: route.problem),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (route.needsReoptimization) ...[
          const ErrorBanner(message: SharedRoute.recalculationWarning),
          const SizedBox(height: AppSpacing.sm),
        ],
        LiveMap(
          height: 230,
          cameraPadding: const EdgeInsets.all(32),
          route: route.navigationGeometry,
          routeSegments: route.navigationLegPoints,
          segmentsMode: provider.routeDisplay == RouteDisplayMode.segments,
          routeStops: route.stops,
          // The next stop is drawn in the accent, like the passenger's own.
          nextStopSequence: next?.stop.sequence,
          onToggleSegments: provider.hasSegmentedRoute
              ? provider.toggleRouteDisplay
              : null,
          vehicles: [
            if (lat != null && lng != null)
              MapVehicle(
                id: '${vehicle!.id}',
                lat: lat,
                lng: lng,
                label: vehicle.licensePlate,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (route.needsReoptimization)
          const InfoRow(label: 'Navigation', value: 'Waiting for updated route')
        else if (next == null)
          const InfoRow(
            icon: Icons.check_circle_outline,
            label: 'No stops left',
            value: 'Every ride on this route is done.',
          )
        else ...[
          InfoRow(
            icon: Icons.navigation_outlined,
            label: 'Next stop',
            value:
                'Stop ${next.stop.sequence + 1} · '
                '${_stopKind(next.stop)} · ${_rideCount(next.stop)}',
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            provider.pendingStopCount > 1
                ? '${_distanceLabel(next)} · '
                      '${provider.pendingStopCount} stops to go'
                : '${_distanceLabel(next)} · last stop',
            style: AppType.small.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  /// Straight-line distance to the stop with the ride's own average speed, so
  /// the figure is an estimate until a real navigation pass exists.
  static String _distanceLabel(RouteNextStop next) {
    final metres = next.distanceMeters;
    if (metres == null) return 'Waiting for your position';
    final distance = metres >= 1000
        ? '${(metres / 1000).toStringAsFixed(1)} km'
        : '${(metres / 10).round() * 10} m';
    final minutes = next.minutes;
    return minutes == null ? distance : '$distance · ~$minutes min';
  }

  static String _stopKind(RouteStop stop) => switch (stop.waypointType) {
    'pickup' => 'Pickup',
    'destination' => 'Drop-off',
    'depot' => 'Depot',
    _ => 'Stop',
  };

  /// Rides served at a stop — the solver pools several onto one boarding stop.
  static String _rideCount(RouteStop stop) => stop.passengerIds.length == 1
      ? '1 ride'
      : '${stop.passengerIds.length} rides';
}

/// Entry card into the dedicated Carpool Run screen — the only place carpool
/// riders are driven from, so the normal dashboard never controls them.
class _CarpoolRunEntry extends StatelessWidget {
  const _CarpoolRunEntry({required this.provider});

  final DriverProvider provider;

  @override
  Widget build(BuildContext context) {
    final route = provider.assignedRoute!;
    final accepted = provider.carpoolAccepted;
    void open() => Navigator.pushNamed(context, '/carpool-run');

    return AppCard(
      onTap: open,
      emphasis: !accepted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            eyebrow: 'Carpool',
            title: accepted
                ? 'Carpool run in progress'
                : 'Carpool run assigned',
            subtitle:
                '${provider.carpoolRiderCount} / ${provider.carpoolCapacity} passengers · '
                '${route.stops.length} stops',
            trailing: StatusBadge(status: accepted ? 'accepted' : 'pending'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: accepted ? 'Open Carpool Run' : 'Review & accept run',
            icon: Icons.alt_route,
            onPressed: open,
          ),
        ],
      ),
    );
  }
}

/// Dispatch board row: route pair + status + the one next action.
class _DriverRideCard extends StatelessWidget {
  const _DriverRideCard({
    required this.ride,
    required this.busy,
    this.onAccept,
    this.onAdvance,
  });

  final RideRequestRecord ride;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onAdvance;

  @override
  Widget build(BuildContext context) {
    final next = switch (ride.status) {
      'assigned' => 'Mark arriving',
      'arriving' => 'Start trip',
      'in_progress' => 'Complete trip',
      _ => null,
    };

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Ride #${ride.id}', style: AppType.smallStrong),
              ),
              StatusBadge(status: ride.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          RouteLeg(
            pickup: ride.pickupLabel,
            destination: ride.destinationLabel,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ride.rideOptionName ?? 'Standard'} tier',
                  style: AppType.small.copyWith(color: AppColors.textSecondary),
                ),
              ),
              AppButton(
                label: onAccept != null ? 'Accept' : (next ?? 'View'),
                variant: AppButtonVariant.primary,
                loading: busy,
                expand: false,
                onPressed: busy ? null : (onAccept ?? onAdvance),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
