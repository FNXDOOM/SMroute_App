import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle_animation.dart';
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
    this.vehicleAnimation,
    this.followVehicle = false,
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

  /// A path for the ride's own vehicle to walk, derived from the ride status by
  /// `RideVehicleAnimation`. The walk continues from wherever the vehicle is
  /// already drawn, so a status change, a new route or a fresh GPS fix retargets
  /// the motion instead of restarting it. Null means no vehicle is under ride
  /// control (nothing is assigned yet, or the ride has finished).
  final VehicleAnimation? vehicleAnimation;

  /// Track the animated vehicle with the camera — the site's `followCamera`,
  /// which it enables only while the trip is in progress.
  final bool followVehicle;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();
  bool _ready = false;

  /// Basemap + its tile provider. The provider is created once per source so
  /// its HTTP client is reused rather than rebuilt on every camera update.
  MapTileSource? _source;
  NetworkTileProvider? _tileProvider;
  String? _providerForSource;

  // ── Vehicle motion ────────────────────────────────────────────────────────
  //
  // Two mechanisms, both ported from the website's `AppMap`:
  //
  //  * a path *walk* for the ride's own vehicle — `RideVehicleAnimation` turns
  //    the ride status into a polyline, and the car advances along it at a
  //    constant ground rate, rotated to the segment heading;
  //  * a smooth *retarget* for every other position update (a real fix arriving
  //    over `/tracking/ws` or the 4 s poll) — the marker eases from where it is
  //    drawn right now to the new point over 1200 ms, so an update never
  //    teleports it and an update landing mid-flight retargets the motion
  //    rather than restarting it from the old point.
  //
  // One ticker drives both, runs only while something is actually moving, and
  // only the vehicle marker layer listens to [_motionFrame] — a moving car
  // never rebuilds the tiles, the route or the rest of the screen.
  final Map<String, _VehicleMotion> _motions = <String, _VehicleMotion>{};
  final Map<String, String> _vehicleLabels = <String, String>{};
  final ValueNotifier<int> _motionFrame = ValueNotifier<int>(0);

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Vehicle currently walking [LiveMap.vehicleAnimation], and that animation's
  /// key, so an unchanged animation leaves the in-flight walk alone.
  String? _walkVehicleId;
  String? _walkKey;

  /// Movement below this is GPS jitter, not travel — animating it would make
  /// the marker jiggle in place at every poll.
  static const double _jitterMeters = 2;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    // Seed from the state the backend already reports: opening or reopening the
    // screen paints the vehicle where it is now rather than animating it in
    // from a previous session's stale point.
    _syncVehicles(widget.vehicles, seed: true);
    _applyAnimation(widget.vehicleAnimation);
    _syncTicker();

    final override = widget.tileSource;
    if (override != null) {
      _applySource(override);
    } else {
      MapTiles.resolve().then((source) {
        if (mounted) setState(() => _applySource(source));
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motionFrame.dispose();
    super.dispose();
  }

  /// Reconciles the drawn vehicles with a new list from the ride provider.
  ///
  /// [seed] adopts positions without animating, for first paint.
  void _syncVehicles(List<MapVehicle> vehicles, {bool seed = false}) {
    final present = <String>{};

    for (final vehicle in vehicles) {
      if (!vehicle.lat.isFinite || !vehicle.lng.isFinite) continue;
      present.add(vehicle.id);
      final label = vehicle.label;
      if (label != null) _vehicleLabels[vehicle.id] = label;

      final target = GeoPoint(vehicle.lat, vehicle.lng);
      final motion = _motions[vehicle.id];
      if (motion == null) {
        _motions[vehicle.id] = _VehicleMotion(target);
        continue;
      }
      // While a path animation owns this marker, the ride drives it; a polled
      // coordinate must not yank it off the route.
      if (vehicle.id == _walkVehicleId) continue;

      if (seed || distanceMeters(motion.rendered, target) <= _jitterMeters) {
        motion.rendered = target;
        continue;
      }
      motion.retargetTo(target);
    }

    // Retire markers that are gone — never the walked one, which the ride
    // animation owns rather than `vehicles`, and never one still moving, so a
    // car that was withdrawn mid-glide runs its motion out instead of being
    // deleted by an unrelated rebuild. It is collected on the next update
    // after it settles.
    _motions.removeWhere(
      (id, motion) =>
          !present.contains(id) &&
          id != _walkVehicleId &&
          !motion.isAnimating,
    );
  }

  /// Starts, retargets or stops the ride's path walk.
  void _applyAnimation(VehicleAnimation? animation) {
    final usable = (animation != null && animation.isUsable) ? animation : null;

    if (usable == null) {
      // The ride finished, was cancelled, or lost its vehicle. A walk already
      // in flight is allowed to run to the end of its path so the car settles
      // at the destination instead of freezing mid-street; nothing new starts.
      final walking = _walkVehicleId;
      if (walking != null) {
        final motion = _motions[walking];
        if (motion != null && motion.walking) {
          motion.finishOnly = true;
        } else {
          _motions.remove(walking);
        }
      }
      _walkVehicleId = null;
      _walkKey = null;
      return;
    }

    // Same motion — leave the walk exactly where it is (site: `animationKey`).
    if (usable.key == _walkKey) return;

    final previousGoal = _walkVehicleId == null
        ? null
        : _motions[_walkVehicleId!]?.path?.last;
    final path = usable.retargetPath(
      current: _motions[usable.vehicleId]?.rendered,
      previousGoal: previousGoal,
    );
    if (path.length < 2) return;

    // A different vehicle took over (a real one replacing the simulated
    // stand-in) — drop the old marker so two cars can't share the screen.
    if (_walkVehicleId != null && _walkVehicleId != usable.vehicleId) {
      _motions.remove(_walkVehicleId);
    }

    final motion = _motions.putIfAbsent(
      usable.vehicleId,
      () => _VehicleMotion(path.first),
    );
    motion
      ..clearTween()
      // `retargetPath` guarantees `path.first` is the rendered position, so
      // this continues the walk rather than jumping to the authored start.
      ..rendered = path.first
      ..path = path
      ..elapsedMs = 0
      ..durationMs = usable.scaledDuration(path).inMilliseconds.toDouble()
      ..loop = usable.loop
      ..finishOnly = false;

    _walkVehicleId = usable.vehicleId;
    _walkKey = usable.key;
  }

  /// Runs the ticker only while something is moving, so an idle map (and an
  /// idle phone battery) is untouched.
  void _syncTicker() {
    final moving = _motions.values.any((motion) => motion.isAnimating);
    if (moving && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final deltaMs = (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    if (deltaMs <= 0) return;

    var moving = false;
    for (final motion in _motions.values) {
      if (motion.advance(deltaMs)) moving = true;
    }

    _motionFrame.value++; // repaints the vehicle layer only
    if (!moving) _ticker.stop();

    final walking = _walkVehicleId;
    if (widget.followVehicle && _ready && walking != null) {
      final position = _motions[walking]?.rendered;
      if (position != null) {
        // Match the site: follow at least the tracking zoom, never zoom out.
        _controller.move(
          LatLng(position.lat, position.lng),
          math.max(widget.followZoom, _controller.camera.zoom),
        );
      }
    }
  }

  List<Marker> _vehicleMarkers() {
    final markers = <Marker>[];
    for (final entry in _motions.entries) {
      final motion = entry.value;
      final position = motion.rendered;
      final bearing = motion.bearingDegrees;
      final marker = _VehicleMarker(label: _vehicleLabels[entry.key]);
      markers.add(
        Marker(
          point: LatLng(position.lat, position.lng),
          width: 44,
          height: 44,
          // `Marker.rotate` only counter-rotates against the map; a heading is
          // applied to the child, as flutter_map's own docs direct.
          child: bearing == null
              ? marker
              : Transform.rotate(angle: bearing * math.pi / 180, child: marker),
        ),
      );
    }
    return markers;
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

    // Motion first: a new GPS fix retargets the marker, a new ride animation
    // (status change, route arriving late, real vehicle replacing the stand-in)
    // starts a continuous walk from where the car is currently drawn.
    _syncVehicles(widget.vehicles);
    _applyAnimation(widget.vehicleAnimation);
    _syncTicker();

    // Follow mode takes precedence over fitting: while a trip is in progress
    // the camera tracks the vehicle rather than the whole route. Ignored while
    // the ticker is driving the camera, so the two can't fight each other.
    final follow = widget.followPoint;
    if (follow != null) {
      if (widget.followVehicle) return;
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

        // Pickup and drop-off never move, so they stay outside the motion
        // listener and are not rebuilt on every animation frame.
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
          ],
        ),

        // The only layer that repaints while a vehicle moves.
        ListenableBuilder(
          listenable: _motionFrame,
          builder: (context, _) => MarkerLayer(markers: _vehicleMarkers()),
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

/// How one vehicle marker is moving.
///
/// The key invariant: this holds where the marker is drawn **right now**, never
/// a target it is still travelling to. That is what lets every new input — a
/// GPS fix, a status change, a route that arrived late — continue from the
/// position the user is actually looking at, instead of snapping or restarting.
class _VehicleMotion {
  _VehicleMotion(this.rendered);

  /// Discrete position updates ease over this long (site `syncMarkers`).
  static const double _retargetMs = 1200;

  /// Below this a new fix is jitter, not travel, and must not spin the marker.
  static const double _minHeadingMeters = 1;

  /// Where the marker is drawn.
  GeoPoint rendered;

  /// Heading in compass degrees; kept when a sample has none, so a stationary
  /// car does not snap back to north.
  double? bearingDegrees;

  GeoPoint? _tweenFrom;
  GeoPoint? _tweenTo;
  double _tweenElapsedMs = 0;
  double _tweenMs = 0;

  /// Path walk (site `animateVehicleAlongPath`). Null once finished, which is
  /// what parks the vehicle at the end of its route.
  List<GeoPoint>? path;
  double elapsedMs = 0;
  double durationMs = 0;
  bool loop = false;

  /// Set when the ride finished mid-walk: the current path may only run to its
  /// end, and must not restart.
  bool finishOnly = false;

  bool get _tweening => _tweenFrom != null && _tweenTo != null && _tweenMs > 0;
  bool get walking => path != null && path!.length >= 2 && durationMs > 0;

  /// True while this marker is still moving.
  bool get isAnimating => _tweening || walking;

  /// Ease from the current rendered position to [target].
  ///
  /// Called again mid-flight this re-targets from the current position, so the
  /// marker never jumps back to where the previous update started.
  void retargetTo(GeoPoint target) {
    // Heading turns immediately, position eases — same split as the site.
    if (distanceMeters(rendered, target) > _minHeadingMeters) {
      bearingDegrees = bearingBetween(rendered, target);
    }
    _tweenFrom = rendered;
    _tweenTo = target;
    _tweenElapsedMs = 0;
    _tweenMs = _retargetMs;
  }

  void clearTween() {
    _tweenFrom = null;
    _tweenTo = null;
    _tweenElapsedMs = 0;
    _tweenMs = 0;
  }

  /// Advance by [deltaMs]; returns true while still moving.
  bool advance(double deltaMs) {
    if (_tweening) {
      _tweenElapsedMs += deltaMs;
      final t = (_tweenElapsedMs / _tweenMs).clamp(0.0, 1.0);
      final eased = t * t * (3 - 2 * t); // smoothstep — site parity
      rendered = _lerpGeo(_tweenFrom!, _tweenTo!, eased);
      if (t >= 1) clearTween();
    }

    if (walking) {
      elapsedMs += deltaMs;
      var t = elapsedMs / durationMs;
      if (t >= 1) {
        if (loop && !finishOnly) {
          elapsedMs %= durationMs;
          t = elapsedMs / durationMs;
        } else {
          t = 1;
        }
      }

      final sample = samplePath(path!, t);
      if (sample != null) {
        rendered = sample.position;
        final heading = sample.bearingDegrees;
        if (heading != null) bearingDegrees = heading;
      }

      // Walk complete: park here. This is what stops the vehicle at the pickup
      // and at the destination instead of looping back to the start.
      if (t >= 1) path = null;
    }

    return isAnimating;
  }
}

GeoPoint _lerpGeo(GeoPoint a, GeoPoint b, double ratio) => GeoPoint(
      a.lat + (b.lat - a.lat) * ratio,
      a.lng + (b.lng - a.lng) * ratio,
    );
