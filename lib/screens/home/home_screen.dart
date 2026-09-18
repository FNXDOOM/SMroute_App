import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';

import '../../models/mock_data.dart';
import '../../models/ride_request_record.dart';
import '../../models/ride_stage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/live_map.dart';
import '../../widgets/ride_option_card.dart';
import '../../widgets/ui_kit.dart';

/// Home — the website's booking surface, rebuilt map-first.
///
/// The site's signature layout is a full-bleed map with a floating booking
/// panel (`PassengerView`: `.map-surface` + `.booking-panel`). On a phone that
/// panel is a draggable sheet, so the map stays the dominant surface and the
/// primary action is always within thumb reach.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _destController = TextEditingController();
  final FocusNode _destFocus = FocusNode();

  /// Last system-back press at the root (double-back-to-exit window).
  DateTime? _lastBackAt;

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _suggesting = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<RideProvider>();
      // Seed the default tier exactly like the website (SwiftX preselected).
      if (provider.selectedOption == null) {
        provider.selectOption(MockData.rideOptions.first);
      }
      context.read<NotificationProvider>().loadNotifications(
        connectRealtime: true,
      );
      provider.loadMyRides(silent: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _destController.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.surface,
        ),
      );
  }

  // ── Destination autocomplete (site: 350ms debounce, 3-char minimum) ──────

  void _onDestinationChanged(String value) {
    final provider = context.read<RideProvider>();
    provider.setDestination(value);
    _debounce?.cancel();

    if (value.trim().length < 3) {
      if (_suggestions.isNotEmpty || _suggesting) {
        setState(() {
          _suggestions = const [];
          _suggesting = false;
        });
      }
      return;
    }

    setState(() => _suggesting = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await provider.suggestPlaces(value.trim());
      if (!mounted || _destController.text.trim() != value.trim()) return;
      setState(() {
        _suggestions = results;
        _suggesting = false;
      });
    });
  }

  void _chooseDestination(PlaceSuggestion place) {
    context.read<RideProvider>().setDestinationPoint(place);
    _destController.text = place.label;
    _destController.selection = TextSelection.collapsed(
      offset: place.label.length,
    );
    _destFocus.unfocus();
    setState(() => _suggestions = const []);
  }

  // ── Pickup: GPS or "choose on map" (site's two pickup actions) ───────────

  Future<void> _useGps() async {
    setState(() => _locating = true);
    final result = await LocationService.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);

    if (result.ok && result.point != null) {
      context.read<RideProvider>().setPickup(
        point: result.point!,
        label: result.label ?? 'Current location',
      );
      return;
    }
    _snack(
      result.error ?? 'Unable to determine your current location.',
      isError: true,
    );
  }

  /// Opens the full-screen picker on the map for either end of the trip and
  /// syncs the destination field when the user picks a drop-off.
  Future<void> _openPicker(String field) async {
    _destFocus.unfocus();
    setState(() => _suggestions = const []);
    await Navigator.pushNamed(context, '/ride-select', arguments: field);
    if (!mounted) return;
    final destination = context.read<RideProvider>().destination;
    if (destination != null && destination != _destController.text) {
      _destController.text = destination;
      _destController.selection = TextSelection.collapsed(
        offset: destination.length,
      );
    }
  }

  // ── Booking ─────────────────────────────────────────────────────────────

  Future<void> _requestRide() async {
    final provider = context.read<RideProvider>();
    _destFocus.unfocus();

    // Free text is resolved through the backend geocoder before booking —
    // coordinates must come from the same authority that validates them.
    if (provider.destinationPoint == null) {
      final text = _destController.text.trim();
      if (text.isEmpty) {
        _snack('Enter a destination', isError: true);
        return;
      }
      final place = await provider.searchPlace(text);
      if (!mounted) return;
      if (place == null) {
        _snack('Could not find "$text". Try a nearby landmark.', isError: true);
        return;
      }
      provider.setDestinationPoint(place);
      _destController.text = place.label;
    }

    final ok = await provider.confirmBooking();
    if (!mounted) return;
    if (ok) {
      setState(() => _suggestions = const []);
      _snack('Ride requested! Finding nearby riders to pool with…');
    } else {
      _snack(
        provider.error ?? 'Booking failed. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _cancelRide() async {
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
    _snack(
      ok ? 'Ride cancelled' : (provider.error ?? 'Cannot cancel this ride'),
      isError: !ok,
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Tab switching keeps a bounded stack: return to the app's root (Home)
  /// without rebuilding it, then push the target tab on top. System back /
  /// edge-swipe from the tab then pops back to Home — instead of
  /// pushReplacementNamed, which made every tab the stack root and left back
  /// with nothing to pop (it exited the app).
  void _go(String route) {
    Navigator.popUntil(context, (route) => route.isFirst);
    if (route != '/') {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AuthProvider, String>(
      (a) => a.currentUser?.firstName ?? 'Rider',
    );
    final notifCount = context.select<NotificationProvider, int>(
      (n) => n.unreadCount,
    );
    final provider = context.watch<RideProvider>();
    final active = provider.activeRideRecord;
    final hasRide = provider.currentRideId != null;

    // Authoritative map geometry: the live booking selection, falling back to
    // the ride record hours-old state can't reproduce (e.g. restart mid-ride).
    final pickupPoint =
        provider.pickupPoint ??
        (active == null ? null : GeoPoint(active.pickupLat, active.pickupLng));
    final destPoint =
        provider.destinationPoint ??
        (active == null ? null : GeoPoint(active.destLat, active.destLng));
    final vehicle = provider.assignedVehicle;
    final hasVehicle = vehicle?.lat != null && vehicle?.lng != null;

    return PopScope<bool>(
      // Root of the app: system back must NOT silently exit (Google Maps
      // pattern). First back = toast; second back within 2s = let it go.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackAt == null ||
            now.difference(_lastBackAt!) > const Duration(seconds: 2)) {
          _lastBackAt = now;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit Smroute'),
                duration: Duration(seconds: 2),
              ),
            );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            Expanded(
              child: MapFirstScaffold(
                map: LiveMap(
                  fullBleed: true,
                  pickup: pickupPoint,
                  destination: destPoint,
                  route: provider.routeEstimate?.geometry ?? const [],
                  vehicles: hasVehicle
                      ? [
                          MapVehicle(
                            id: '${vehicle!.id}',
                            lat: vehicle.lat!,
                            lng: vehicle.lng!,
                            label: vehicle.licensePlate,
                          ),
                        ]
                      : const [],
                  initialCenter: pickupPoint ?? GeocodingService.defaultPickup,
                  attribution: false,
                  cameraPadding: const EdgeInsets.fromLTRB(48, 132, 48, 300),
                ),
                topBar: _MapTopBar(
                  greeting: _greeting(),
                  firstName: firstName.isEmpty ? 'Rider' : firstName,
                  notifCount: notifCount,
                  onInbox: () => _go('/inbox'),
                  onProfile: () => _go('/profile'),
                ),
                sheet: AppDraggableSheet(
                  initialSize: hasRide ? 0.56 : 0.52,
                  builder: (context, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      0,
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                    ),
                    children: [
                      // ── Active ride takes over the panel (site behaviour) ──
                      if (hasRide) ...[
                        _ActiveRidePanel(
                          provider: provider,
                          ride: active,
                          onTrack: () =>
                              Navigator.pushNamed(context, '/ride-confirm'),
                          onCancel: _cancelRide,
                          onDismiss: provider.dismissActiveRide,
                          onPay: () async {
                            final ok = await provider.payActiveRideFare();
                            if (!mounted) return;
                            _snack(
                              ok
                                  ? 'Payment successful — your fare has been '
                                      'received.'
                                  : (provider.paymentError ??
                                        'Payment not completed'),
                              isError: !ok,
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // ── Booking form ──────────────────────────────────────
                      if (!hasRide) ...[
                        const SheetHeader(
                          eyebrow: 'Request a ride',
                          title: 'Where to?',
                          subtitle: 'Flat fares · No surge · Shared options',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PickupField(
                          label: provider.pickupLabel,
                          confirmed: provider.pickupConfirmed,
                          locating: _locating,
                          onUseGps: _useGps,
                          onPickOnMap: () => _openPicker('pickup'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PlaceField(
                          marker: PlaceMarker.square,
                          controller: _destController,
                          focusNode: _destFocus,
                          hint: 'Where to?',
                          onChanged: _onDestinationChanged,
                          onSubmitted: (_) => _requestRide(),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _destController,
                                builder: (context, value, _) =>
                                    value.text.isEmpty
                                    ? const SizedBox.shrink()
                                    : IconSquareButton(
                                        icon: Icons.close,
                                        size: 36,
                                        tooltip: 'Clear',
                                        onTap: () {
                                          _destController.clear();
                                          context
                                              .read<RideProvider>()
                                              .setDestination('');
                                          setState(
                                            () => _suggestions = const [],
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              IconSquareButton(
                                icon: Icons.map_outlined,
                                size: 36,
                                tooltip: 'Choose on map',
                                onTap: () => _openPicker('destination'),
                              ),
                            ],
                          ),
                        ),

                        // Suggestions (site: dark popover under the field).
                        AnimatedSize(
                          duration: AppMotion.base,
                          curve: AppMotion.enter,
                          alignment: Alignment.topCenter,
                          child: _suggesting
                              ? const Padding(
                                  padding: EdgeInsets.only(top: AppSpacing.sm),
                                  child: SkeletonRows(count: 2, height: 52),
                                )
                              : _suggestions.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.xs,
                                  ),
                                  child: Column(
                                    children: [
                                      for (final place in _suggestions.take(5))
                                        PlaceSuggestionTile(
                                          title: place.label
                                              .split(',')
                                              .first
                                              .trim(),
                                          subtitle: place.label,
                                          onTap: () =>
                                              _chooseDestination(place),
                                        ),
                                    ],
                                  ),
                                ),
                        ),

                        // Route estimate + live traffic (site rows).
                        AnimatedSize(
                          duration: AppMotion.base,
                          curve: AppMotion.enter,
                          alignment: Alignment.topCenter,
                          child: _routeSection(provider),
                        ),

                        const SizedBox(height: AppSpacing.md),
                        const SectionLabel('Choose a ride'),
                        const SizedBox(height: AppSpacing.sm),
                        for (final option in MockData.rideOptions)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: RideOptionCard(
                              ride: option,
                              isSelected:
                                  provider.selectedOption?.id == option.id,
                              onTap: () => provider.selectOption(option),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        if (provider.error != null) ...[
                          ErrorBanner(message: provider.error!),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        AppButton(
                          label: 'Request ride',
                          loading: provider.isBooking,
                          onPressed: _requestRide,
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      // ── Recent rides (real backend data) ───────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Text('Recent rides', style: AppType.title),
                          ),
                          TextButton(
                            onPressed: () => _go('/trips'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all',
                                  style: AppType.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (provider.isLoadingRides && provider.myRides.isEmpty)
                        const SkeletonRows(count: 3, height: 58)
                      else if (provider.myRides.isEmpty)
                        const EmptyState(
                          compact: true,
                          icon: Icons.trip_origin,
                          title: 'No rides yet',
                          hint:
                              'Your recent bookings will appear here once you '
                              'request your first ride.',
                        )
                      else
                        for (final ride in provider.myRides.take(3))
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: _TripRow(
                              ride: ride,
                              onTap: () => _go('/trips'),
                            ),
                          ),

                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Map data © OpenStreetMap contributors · CARTO',
                        style: AppType.caption.copyWith(
                          color: AppColors.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BottomNavBar(
              activeTab: 'home',
              onHome: () {},
              onTrips: () => _go('/trips'),
              onInbox: () => _go('/inbox'),
              onAccount: () => _go('/profile'),
              notifCount: notifCount,
            ),
          ],
        ),
      ),
    );
  }

  /// Route estimate row + the site's "Use live traffic" switch.
  Widget _routeSection(RideProvider provider) {
    final estimate = provider.routeEstimate;
    final hasDestination = provider.destinationPoint != null;

    return Column(
      children: [
        if (provider.isLoadingRoute && hasDestination)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: SkeletonRows(count: 1, height: 44, gap: 0),
          )
        else if (estimate != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: InfoRow(
              icon: Icons.route_outlined,
              label: 'Route estimate',
              value:
                  '${estimate.distanceKm.toStringAsFixed(1)} km · '
                  '${estimate.durationMinutes} min',
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          decoration: AppDecor.flatRow(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Use live traffic for route and ETA',
                  style: AppType.caption.copyWith(color: AppColors.textPrimary),
                ),
              ),
              Switch(
                value: provider.trafficEnabled,
                onChanged: provider.setTrafficEnabled,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Floating top bar over the map: greeting + name, inbox, avatar.
class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.greeting,
    required this.firstName,
    required this.notifCount,
    required this.onInbox,
    required this.onProfile,
  });

  final String greeting;
  final String firstName;
  final int notifCount;
  final VoidCallback onInbox;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SectionLabel(greeting),
                const SizedBox(height: 1),
                Text(
                  firstName,
                  style: AppType.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconSquareButton(
          icon: Icons.inbox_outlined,
          tooltip: 'Inbox',
          badgeCount: notifCount,
          onTap: onInbox,
        ),
        const SizedBox(width: AppSpacing.xs),
        PressableScale(
          onTap: onProfile,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: AppRadius.all(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              firstName.isEmpty ? 'R' : firstName[0].toUpperCase(),
              style: AppType.title.copyWith(color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pickup row: the confirmed label, GPS action, and tap-to-pick-on-map.
class _PickupField extends StatelessWidget {
  const _PickupField({
    required this.label,
    required this.confirmed,
    required this.locating,
    required this.onUseGps,
    required this.onPickOnMap,
  });

  final String label;
  final bool confirmed;
  final bool locating;
  final VoidCallback onUseGps;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPickOnMap,
      child: PlaceField(
        marker: PlaceMarker.dot,
        hint: confirmed ? label : 'Choose pickup · $label',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconSquareButton(
              icon: Icons.my_location,
              size: 36,
              loading: locating,
              tooltip: 'Use GPS',
              color: confirmed ? AppColors.paper : AppColors.textSecondary,
              onTap: onUseGps,
            ),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Active ride panel — the site's emphasised active-booking card: status pill,
/// 6-stage stepper, driver/vehicle row, then Track and Cancel.
class _ActiveRidePanel extends StatelessWidget {
  const _ActiveRidePanel({
    required this.provider,
    required this.ride,
    required this.onTrack,
    required this.onCancel,
    required this.onDismiss,
    required this.onPay,
  });

  final RideProvider provider;
  final RideRequestRecord? ride;
  final VoidCallback onTrack;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final status = ride?.status ?? 'pending';
    final terminal = RideStages.isTerminal(status);
    final vehicle = provider.assignedVehicle;

    if (terminal) {
      final completed = status == 'completed';
      return AppCard(
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Active booking'),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        completed ? 'Ride completed' : 'Ride cancelled',
                        style: AppType.title,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              completed
                  ? 'Thanks for riding with Smroute.'
                  : 'No charge was made for this ride.',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Dismiss · Book new ride', onPressed: onDismiss),
          ],
        ),
      );
    }

    // Backend contract: a manually-accepted ride never gets a vehicle row
    // (PATCH status unlinks virtual_stop_id), so once the ride is assigned a
    // null vehicle is final — show the driver-assigned state instead of a
    // spinner or a false "not available".
    const driverAssigned = {'assigned', 'arriving', 'in_progress'};
    final vehicleLabel = vehicle != null
        ? vehicle.licensePlate
        : driverAssigned.contains(status)
              ? 'Driver assigned'
              : (provider.vehicleAssignmentTimedOut
                    ? 'Not available for this ride'
                    : 'Assigning a vehicle…');

    return AppCard(
      emphasis: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Active booking'),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      ride == null
                          ? 'Your ride'
                          : 'Ride #${ride!.id} · '
                                '${ride!.rideOptionName ?? 'SwiftX'}',
                      style: AppType.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          RideStageStepper(
            stages: RideStages.keys,
            labels: RideStages.labels,
            currentIndex: RideStages.indexOf(status),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: AppDecor.infoRow(),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: AppRadius.all(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    vehicle == null
                        ? 'D'
                        : vehicle.licensePlate.characters.first,
                    style: AppType.title.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The backend exposes no driver identity, so the row
                      // reports the vehicle and stage the server reports.
                      Text(
                        vehicle == null ? 'Your driver' : 'Assigned vehicle',
                        style: AppType.smallStrong,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RideStages.labelOf(status),
                        style: AppType.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          InfoRow(label: 'Vehicle', value: vehicleLabel),
          if (ride != null) ...[
            const SizedBox(height: AppSpacing.xs),
            InfoRow(label: 'Destination', value: ride!.destinationLabel),
          ],
          const SizedBox(height: AppSpacing.md),
          // Website parity: RazorpayPayment renders on the active-ride card
          // for the whole ride (isRideActive), not only after completion.
          AppButton(
            label: provider.paymentPhase == PaymentPhase.paid
                ? 'Fare paid — thank you'
                : 'Pay fare · Razorpay',
            icon: provider.paymentPhase == PaymentPhase.paid
                ? Icons.check_circle_outline
                : Icons.payment_outlined,
            loading: provider.isPaying,
            onPressed: provider.isPaying ||
                    provider.paymentPhase == PaymentPhase.paid
                ? null
                : onPay,
          ),
          if (provider.paymentError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ErrorBanner(message: provider.paymentError!),
          ],
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Track live',
            icon: Icons.navigation_outlined,
            onPressed: onTrack,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Cancel ride',
            variant: AppButtonVariant.secondary,
            destructive: true,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Trip row: destination, time, status badge (site `TripCard`).
class _TripRow extends StatelessWidget {
  const _TripRow({required this.ride, required this.onTap});

  final RideRequestRecord ride;
  final VoidCallback onTap;

  static String _time(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '→ ${ride.destinationLabel}',
                  style: AppType.smallStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ride.requestTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _time(ride.requestTime),
                    style: AppType.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(status: ride.status),
        ],
      ),
    );
  }
}
