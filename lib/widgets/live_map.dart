import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

/// A vehicle position to draw on the map.
class MapVehicle {
  final String id;
  final double lat;
  final double lng;
  final String? label;

  const MapVehicle({
    required this.id,
    required this.lat,
    required this.lng,
    this.label,
  });
}

/// Real interactive map — the Flutter counterpart of the website's MapLibre
/// surface: dark neutral tiles, black/white markers, a route drawn as a solid
/// white line with a soft dark casing (the site's "Uber-style clarity"), plus
/// tap-to-pick and a locate action.
///
/// Tile source is a keyless dark raster style so no client-side map key is
/// ever shipped. The website's own Stadia style (`/maps/stadia/style.json`)
/// is auth-protected and MapLibre's native tile fetches can't carry our
/// bearer token — see README.md §Feature status for the swap path.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    this.pickup,
    this.destination,
    this.route = const [],
    this.vehicles = const [],
    this.onPick,
    this.onLocate,
    this.locating = false,
    this.height,
    this.interactive = true,
    this.initialCenter = const GeoPoint(12.9716, 77.5946),
    this.initialZoom = 12.5,
    this.attribution = true,
    this.fullBleed = false,
    this.cameraPadding = const EdgeInsets.all(48),
    this.followPoint,
    this.followZoom = 15.5,
  });

  final GeoPoint? pickup;
  final GeoPoint? destination;

  /// Ordered route polyline.
  final List<GeoPoint> route;
  final List<MapVehicle> vehicles;

  /// Fires when the user taps the map (used for "Choose on map").
  final ValueChanged<GeoPoint>? onPick;
  final VoidCallback? onLocate;
  final bool locating;
  final double? height;
  final bool interactive;
  final GeoPoint initialCenter;
  final double initialZoom;
  final bool attribution;

  /// Edge-to-edge map with no card border/radius — the map-first layout where
  /// the map is the screen and a sheet floats over its lower half.
  final bool fullBleed;

  /// Padding used when fitting the camera to pickup/drop-off/route. Widen the
  /// bottom inset on map-first screens so markers never sit behind the sheet.
  final EdgeInsets cameraPadding;

  /// When set, the camera follows this moving point (the site's `followCamera`
  /// during a live trip) instead of staying where the user left it.
  final GeoPoint? followPoint;
  final double followZoom;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  /// Signature of the last camera fit, so we re-fit only when the geometry
  /// actually changes (never fighting the user's own panning).
  String _lastFitSignature = '';

  String get _fitSignature {
    final r = widget.route;
    if (r.length >= 2) {
      return 'r:${r.length}:${r.first.lat},${r.first.lng}:'
          '${r.last.lat},${r.last.lng}';
    }
    return 'p:${widget.pickup?.lat},${widget.pickup?.lng}:'
        '${widget.destination?.lat},${widget.destination?.lng}';
  }

  void _fitToContent() {
    if (!_ready) return;
    final points = <LatLng>[
      ...widget.route.map((p) => LatLng(p.lat, p.lng)),
      if (widget.pickup != null) LatLng(widget.pickup!.lat, widget.pickup!.lng),
      if (widget.destination != null)
        LatLng(widget.destination!.lat, widget.destination!.lng),
    ];
    if (points.length < 2) return;

    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: widget.cameraPadding,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Follow mode takes precedence over fitting: while a trip is in progress
    // the camera tracks the vehicle rather than the whole route.
    final follow = widget.followPoint;
    if (follow != null) {
      final previous = oldWidget.followPoint;
      final moved =
          previous == null ||
          previous.lat != follow.lat ||
          previous.lng != follow.lng;
      if (moved && _ready) {
        _lastFitSignature = _fitSignature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.followPoint == null) return;
          _controller.move(LatLng(follow.lat, follow.lng), widget.followZoom);
        });
      }
      return;
    }

    final signature = _fitSignature;
    if (signature != _lastFitSignature) {
      _lastFitSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToContent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = widget.route
        .map((p) => LatLng(p.lat, p.lng))
        .toList(growable: false);

    final map = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: LatLng(
          widget.initialCenter.lat,
          widget.initialCenter.lng,
        ),
        initialZoom: widget.initialZoom,
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: AppColors.surface,
        onMapReady: () {
          _ready = true;
          _lastFitSignature = _fitSignature;
          _fitToContent();
        },
        onTap: widget.onPick == null
            ? null
            : (tapPosition, point) =>
                  widget.onPick!(GeoPoint(point.latitude, point.longitude)),
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.finalyr_app',
          maxNativeZoom: 19,
          tileBuilder: _darkTileBuilder,
        ),

        // Route: soft casing under a solid line (site recipe).
        if (routePoints.length >= 2) ...[
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 9,
                color: AppColors.bg,
              ),
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 4.5,
                color: AppColors.paper,
              ),
            ],
          ),
        ],

        MarkerLayer(
          markers: [
            if (widget.destination != null)
              Marker(
                point: LatLng(widget.destination!.lat, widget.destination!.lng),
                width: 26,
                height: 26,
                child: const _DestinationMarker(),
              ),
            if (widget.pickup != null)
              Marker(
                point: LatLng(widget.pickup!.lat, widget.pickup!.lng),
                width: 42,
                height: 42,
                child: const _PickupMarker(),
              ),
            for (final v in widget.vehicles)
              Marker(
                point: LatLng(v.lat, v.lng),
                width: 44,
                height: 44,
                child: _VehicleMarker(label: v.label),
              ),
          ],
        ),

        if (widget.attribution)
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('OpenStreetMap contributors'),
              TextSourceAttribution('CARTO'),
            ],
            alignment: AttributionAlignment.bottomLeft,
          ),
      ],
    );

    final surface = Stack(
      children: [
        Positioned.fill(child: map),
        if (widget.onLocate != null)
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Material(
              color: AppColors.bg,
              borderRadius: AppRadius.all(AppRadius.md),
              child: InkWell(
                onTap: widget.locating ? null : widget.onLocate,
                borderRadius: AppRadius.all(AppRadius.md),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.all(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: widget.locating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.paper,
                          ),
                        )
                      : const Icon(
                          Icons.my_location,
                          size: 18,
                          color: AppColors.paper,
                        ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.fullBleed) {
      return SizedBox(height: widget.height, child: surface);
    }

    return ClipRRect(
      borderRadius: AppRadius.all(AppRadius.lg),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: AppRadius.all(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: surface,
      ),
    );
  }

  /// Keeps tiles reading as the same neutral surface the site uses when a
  /// tile is missing/slow — avoids white flashes against the black canvas.
  Widget _darkTileBuilder(
    BuildContext context,
    Widget tile,
    TileImage tileImage,
  ) {
    return ColoredBox(color: AppColors.surfaceAlt, child: tile);
  }
}

/// Pickup: white dot with a translucent aura (site's pulsing pickup marker).
class _PickupMarker extends StatelessWidget {
  const _PickupMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.tint(AppColors.paper, 0.18),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.paper,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bg, width: 3),
          ),
        ),
      ),
    );
  }
}

/// Drop-off: white rounded square (site's square drop-off marker).
class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(color: AppColors.bg, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: AppRadius.all(2),
        ),
      ),
    );
  }
}

/// Vehicle: white tile with a line icon (site's 44px vehicle marker).
class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: AppRadius.all(AppRadius.md),
          border: Border.all(color: AppColors.bg, width: 2),
          boxShadow: AppShadows.sm,
        ),
        child: const Icon(Icons.directions_car, size: 17, color: AppColors.ink),
      ),
    );
  }
}
