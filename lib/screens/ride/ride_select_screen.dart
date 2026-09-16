import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ride_provider.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/live_map.dart';
import '../../widgets/ui_kit.dart';

/// Full-screen location picker — the mobile translation of the website's
/// "Choose on map" mode (`mapPickupMode`) and the pickup/destination fields.
///
/// The map is the whole screen; a compact search field floats at the top and a
/// confirm sheet at the bottom. Tapping the map snaps the point to a drivable
/// road and reverse-geocodes it through the backend, so the label a user
/// confirms is the same label the website would store.
///
/// Opened with the target as a route argument: `'pickup'` or `'destination'`.
class RideSelectScreen extends StatefulWidget {
  const RideSelectScreen({super.key});

  @override
  State<RideSelectScreen> createState() => _RideSelectScreenState();
}

class _RideSelectScreenState extends State<RideSelectScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _field = 'destination';
  GeoPoint? _point;
  String _label = '';
  bool _resolving = false;
  bool _gpsLoading = false;
  bool _searched = false;
  List<PlaceSuggestion> _suggestions = const [];

  bool get _isPickup => _field == 'pickup';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      final provider = context.read<RideProvider>();
      setState(() {
        _field = args is String && args == 'pickup' ? 'pickup' : 'destination';
        if (_isPickup) {
          _point = provider.pickupPoint;
          _label = provider.pickupConfirmed ? provider.pickupLabel : '';
        } else {
          _point = provider.destinationPoint;
          _label = provider.destination ?? '';
          _searchController.text = provider.destination ?? '';
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }

  /// Backend is the geocoding authority: snap to a road, then resolve a label.
  Future<void> _adopt(GeoPoint raw) async {
    setState(() {
      _resolving = true;
      _point = raw;
      _label = '';
      _suggestions = const [];
    });

    final snapped = await LocationService.nearestRoad(raw) ?? raw;
    final place = await LocationService.reverse(snapped);
    if (!mounted) return;

    setState(() {
      _resolving = false;
      _point = GeoPoint(place?.lat ?? snapped.lat, place?.lng ?? snapped.lng);
      _label = place?.label ?? '';
    });

    if ((place?.label ?? '').trim().isEmpty) {
      // The backend refuses lookups outside its India service area.
      _snack('That point is outside the service area.');
    }
  }

  Future<void> _useGps() async {
    setState(() => _gpsLoading = true);
    final result = await LocationService.currentPosition();
    if (!mounted) return;
    setState(() => _gpsLoading = false);

    if (result.ok && result.point != null) {
      setState(() {
        _point = result.point;
        _label = result.label ?? 'Current location';
      });
      return;
    }
    _snack(result.error ?? 'Unable to determine your current location.');
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = const [];
        _searched = false;
      });
      return;
    }
    setState(() => _searched = true);
    final provider = context.read<RideProvider>();
    final results = await provider.suggestPlaces(query);
    if (!mounted || _searchController.text.trim() != query) return;
    setState(() => _suggestions = results);
  }

  Future<void> _searchExact() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _searched = true);
    final place = await context.read<RideProvider>().searchPlace(query);
    if (!mounted) return;
    if (place == null) {
      setState(() => _searched = false);
      _snack('No match for "$query". Try a nearby landmark.');
      return;
    }
    setState(() {
      _suggestions = const [];
      _searched = false;
      _point = GeoPoint(place.lat, place.lng);
      _label = place.label;
    });
  }

  void _chooseSuggestion(PlaceSuggestion place) {
    _searchController.text = place.label;
    _searchController.selection = TextSelection.collapsed(
      offset: place.label.length,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _searched = false;
      _point = GeoPoint(place.lat, place.lng);
      _label = place.label;
    });
  }

  void _confirm() {
    final point = _point;
    if (point == null) {
      _snack(
        _isPickup
            ? 'Tap the map or search for a pickup.'
            : 'Tap the map or search for a destination.',
      );
      return;
    }
    final label = _label.trim().isEmpty
        ? '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}'
        : _label.trim();
    final provider = context.read<RideProvider>();

    if (_isPickup) {
      provider.setPickup(point: point, label: label);
    } else {
      provider.setDestinationPoint(
        PlaceSuggestion(lat: point.lat, lng: point.lng, label: label),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    final pickup = _isPickup
        ? _point
        : (provider.pickupPoint ?? GeocodingService.defaultPickup);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MapFirstScaffold(
        map: LiveMap(
          fullBleed: true,
          pickup: pickup,
          destination: _isPickup ? null : _point,
          onPick: _adopt,
          initialCenter: _point ?? pickup ?? GeocodingService.defaultPickup,
          initialZoom: _point == null ? 12.5 : 15.5,
          attribution: false,
          cameraPadding: const EdgeInsets.fromLTRB(48, 150, 48, 260),
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
              child: PlaceField(
                marker: _isPickup ? PlaceMarker.dot : PlaceMarker.square,
                controller: _searchController,
                hint: _isPickup
                    ? 'Search pickup address'
                    : 'Search destination address',
                onChanged: _search,
                onSubmitted: (_) => _searchExact(),
                trailing: IconSquareButton(
                  icon: Icons.search,
                  size: 36,
                  tooltip: 'Search',
                  onTap: _searchExact,
                ),
              ),
            ),
          ],
        ),
        banner: _resolving
            ? const _Pill(text: 'Locating…', showSpinner: true)
            : const _Pill(text: 'Tap the map to choose'),
        sheet: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: SheetPanel(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.gutter,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_suggestions.isNotEmpty || _searched)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: _searched && _suggestions.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                                child: SkeletonRows(count: 3, height: 48),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _suggestions.length,
                                itemBuilder: (context, i) =>
                                    PlaceSuggestionTile(
                                      title: _suggestions[i].label
                                          .split(',')
                                          .first,
                                      subtitle: _suggestions[i].label,
                                      onTap: () =>
                                          _chooseSuggestion(_suggestions[i]),
                                    ),
                              ),
                      ),
                    const SheetHeader(
                      eyebrow: 'Choose on map',
                      title: 'Set the pin',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RouteLeg(
                      pickup: _isPickup
                          ? (_label.isEmpty ? 'Tap the map' : _label)
                          : provider.pickupLabel,
                      destination: _isPickup
                          ? provider.destination ?? 'Not set yet'
                          : (_label.isEmpty ? 'Tap the map' : _label),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: _isPickup
                          ? 'Confirm pickup'
                          : 'Confirm destination',
                      icon: Icons.check,
                      onPressed: _point == null ? null : _confirm,
                    ),
                    if (_isPickup) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: 'Use my current location',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.my_location,
                        loading: _gpsLoading,
                        onPressed: _useGps,
                      ),
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

/// Status pill floated over the map — site recipe (white on black, hairline).
class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.showSpinner = false});

  final String text;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadius.all(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            text,
            style: AppType.badge.copyWith(
              color: AppColors.ink,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
