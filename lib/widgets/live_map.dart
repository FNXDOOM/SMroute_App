import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';
import '../services/map_tiles.dart';
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
/// The basemap is resolved by [MapTiles], which prefers the website's own
/// Stadia tiles served by the backend's authenticated proxy — so both clients
/// draw the same map, and the API key stays server-side. A keyless dark raster
/// is used only if that proxy can't serve tiles (README.md §Maps).
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
    this.tileSource,
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

  /// Overrides basemap resolution — used by callers that have already resolved
  /// one, and by tests so no network probe is needed.
  final MapTileSource? tileSource;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  /// Basemap + its tile provider. The provider is created once per source so
  /// its HTTP client is reused rather than rebuilt on every camera update.
  MapTileSource? _source;
  NetworkTileProvider? _tileProvider;
  String? _providerForSource;

  @override
  void initState() {
    super.initState();
    final override = widget.tileSource;
    if (override != null) {
      _applySource(override);
    } else {
      MapTiles.resolve().then((source) {
        if (mounted) setState(() => _applySource(source));
      });
    }
  }

  void _applySource(MapTileSource source) {
    _source = source;
    // Keyed by source identity only. The session token is resolved per tile
    // request by MapTiles.tileHttpClient, so a refreshed token no longer needs
    // the provider to be rebuilt (and can't leave it holding a stale one).
    final key = '${source.id}|${source.headers['Authorization'] ?? ''}';
    if (_providerForSource != key) {
      _tileProvider = NetworkTileProvider(
        headers: Map.of(source.headers),
        httpClient: MapTiles.tileHttpClient(source),
      );
      _providerForSource = key;
    }
  }

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

    final source = _source;

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
        if (source != null)
          TileLayer(
            urlTemplate: source.urlTemplate,
            subdomains: source.subdomains,
            tileProvider: _tileProvider,
            userAgentPackageName: 'com.example.finalyr_app',
            maxNativeZoom: 19,
            retinaMode: source.retina,
            tileBuilder: (context, tile, tileImage) =>
                _tileBuilder(context, tile, tileImage, source),
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

        if (widget.attribution && source != null)
          RichAttributionWidget(
            attributions: [
              for (final credit in source.attributions)
                TextSourceAttribution(credit),
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

  /// Places a tile on the canvas colour so a missing or slow tile can't flash
  /// lighter squares against the black map, and lifts the fallback basemap's
  /// near-black road casing so its streets are actually legible.
  Widget _tileBuilder(
    BuildContext context,
    Widget tile,
    TileImage tileImage,
    MapTileSource source,
  ) {
    Widget result = ColoredBox(color: AppColors.bg, child: tile);
    if (source.brighten) {
      // out = in + 45 (per channel): #030303→#303030, #111111→#3E3E3E,
      // #222222→#4F4F4F — roughly the website's #545454 road neutral.
      const lift = 45.0;
      result = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          1, 0, 0, 0, lift,
          0, 1, 0, 0, lift,
          0, 0, 1, 0, lift,
          0, 0, 0, 1, 0,
        ]),
        child: result,
      );
    }
    return result;
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
