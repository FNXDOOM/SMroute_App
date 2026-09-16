import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ride_stage.dart';
import '../../providers/ride_provider.dart';
import '../../services/geocoding_service.dart';
import '../../services/routing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/live_map.dart';
import '../../widgets/ui_kit.dart';

/// Live ride tracking — the website's `TrackingView`, made map-first.
///
/// Full-bleed map (pickup, drop-off, route polyline, assigned vehicle) with the
/// camera following the vehicle while the trip is in progress, exactly like the
/// site's `followCamera`. Ride state, stage and cancel rules all come from the
/// backend; nothing about progress is simulated in the UI.
class RideConfirmScreen extends StatefulWidget {
  const RideConfirmScreen({super.key});

  @override
  State<RideConfirmScreen> createState() => _RideConfirmScreenState();
}

class _RideConfirmScreenState extends State<RideConfirmScreen> {
  RouteEstimate? _route;
  String _loadedFor = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  /// Reuses the estimate the booking panel already fetched; only asks the
  /// backend again when the panel has none (e.g. restored session).
  Future<void> _loadRoute() async {
    final provider = context.read<RideProvider>();
    final ride = provider.activeRideRecord;
    if (ride == null) return;
    final key =
        '${ride.id}:${ride.pickupLat},${ride.pickupLng}:'
        '${ride.destLat},${ride.destLng}:${provider.trafficEnabled}';
    if (key == _loadedFor) return;
    _loadedFor = key;

    final existing = provider.routeEstimate;
    if (existing != null) {
      setState(() => _route = existing);
      return;
    }
    final estimate = await RoutingService.route(
      from: GeoPoint(ride.pickupLat, ride.pickupLng),
      to: GeoPoint(ride.destLat, ride.destLng),
      traffic: provider.trafficEnabled,
    );
    if (!mounted) return;
    setState(() => _route = estimate);
  }

  Future<void> _cancel() async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Cancel this ride?',
      message: 'Your driver assignment will be released.',
      confirmLabel: 'Cancel ride',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final provider = context.read<RideProvider>();
    final ok = await provider.cancelActiveRide();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Ride cancelled'
                : (provider.error ?? 'Cannot cancel this ride'),
          ),
        ),
      );
  }

  void _home() =>
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    final ride = provider.activeRideRecord;
    final status = ride?.status ?? '';
    final terminal = RideStages.isTerminal(status);

    if (provider.currentRideId == null || ride == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              children: [
                PageHeader(
                  title: 'Live tracking',
                  description: 'No active ride right now',
                  onBack: () => Navigator.maybePop(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                EmptyState(
                  icon: Icons.navigation_outlined,
                  title: 'No active ride',
                  hint: 'Start a booking from Home to track it live here.',
                  action: AppButton(label: 'Back home', onPressed: _home),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pickup = GeoPoint(ride.pickupLat, ride.pickupLng);
    final destination = GeoPoint(ride.destLat, ride.destLng);
    final route = _route?.geometry ?? const <GeoPoint>[];
    // Narrow the vehicle's nullable coordinates once, so the tree below can't
    // drift out of sync with `hasVehicle`.
    final vehicle = provider.assignedVehicle;
    final vehicleLat = vehicle?.lat;
    final vehicleLng = vehicle?.lng;
    final hasVehicle = vehicleLat != null && vehicleLng != null;
    final vehiclePosition = hasVehicle
        ? '${vehicleLat.toStringAsFixed(4)}, ${vehicleLng.toStringAsFixed(4)}'
        : null;
    final following = status == 'in_progress' && hasVehicle;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MapFirstScaffold(
        map: LiveMap(
          fullBleed: true,
          pickup: pickup,
          destination: destination,
          route: route,
          vehicles: hasVehicle
              ? [
                  MapVehicle(
                    id: '${vehicle?.id}',
                    lat: vehicleLat,
                    lng: vehicleLng,
                    label: vehicle?.licensePlate ?? '',
                  ),
                ]
              : const [],
          initialCenter: pickup,
          attribution: false,
          cameraPadding: const EdgeInsets.fromLTRB(48, 132, 48, 300),
          followPoint: following ? GeoPoint(vehicleLat, vehicleLng) : null,
        ),
        topBar: Row(
          children: [
            IconSquareButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: AppRadius.all(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.paper,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        RideStages.labelOf(status),
                        style: AppType.smallStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasVehicle)
                      Text(
                        vehicle?.licensePlate ?? '',
                        style: AppType.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        sheet: Align(
          alignment: Alignment.bottomCenter,
          // Bounded + scrollable so the panel can never overflow a short
          // screen — the site's panel scrolls, it doesn't clip.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.66,
            ),
            child: SheetPanel(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SheetHeader(
                      eyebrow: 'Live ride',
                      title: 'Ride #${ride.id}',
                      subtitle:
                          '${ride.rideOptionName ?? 'Standard'} · '
                          '${RideStages.labelOf(status)}',
                      trailing: StatusBadge(status: status),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RideStageStepper(
                      stages: RideStages.keys,
                      labels: RideStages.labels,
                      currentIndex: RideStages.indexOf(status),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RouteLeg(
                      pickup: ride.pickupLabel,
                      destination: ride.destinationLabel,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InfoRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Vehicle',
                      value: vehicle != null
                          ? vehicle.licensePlate
                          : (provider.vehicleAssignmentTimedOut
                                ? 'Not available'
                                : 'Assigning…'),
                    ),
                    if (_route != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      InfoRow(
                        icon: Icons.route_outlined,
                        label: 'Route estimate',
                        value:
                            '${_route!.distanceKm.toStringAsFixed(1)} km · '
                            '${_route!.durationMinutes} min',
                      ),
                    ],
                    if (vehiclePosition != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      InfoRow(
                        icon: Icons.my_location,
                        label: 'Vehicle position',
                        value: vehiclePosition,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (terminal) ...[
                      if (status == 'completed')
                        AppButton(
                          label: 'Rate your ride',
                          icon: Icons.star_outline,
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/rating',
                            (_) => false,
                          ),
                        )
                      else
                        AppButton(label: 'Book another ride', onPressed: _home),
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: 'Back to home',
                        variant: AppButtonVariant.secondary,
                        onPressed: _home,
                      ),
                    ] else ...[
                      AppButton(
                        label: 'Back to home',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      if (RideStages.isCancellable(status)) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppButton(
                          label: 'Cancel ride',
                          variant: AppButtonVariant.secondary,
                          destructive: true,
                          onPressed: _cancel,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
