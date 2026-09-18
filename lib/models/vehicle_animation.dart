import 'dart:math' as math;

import '../services/geocoding_service.dart' show GeoPoint;

/// A vehicle position with its heading, produced by [VehicleAnimation.positionAt].
class AnimatedVehicle {
  const AnimatedVehicle({required this.position, this.bearingDegrees});

  final GeoPoint position;

  /// Compass heading in degrees (0 = north, 90 = east), or null when the
  /// heading is unknown (a degenerate/zero-length segment, or the path end).
  /// Callers keep the previous heading when this is null, so a vehicle never
  /// spins back to north while it is standing still.
  final double? bearingDegrees;
}

/// A path of geographic points for one vehicle to walk along, plus how long
/// that walk takes.
///
/// This mirrors the website's `vehicleAnimation` payload
/// (`frontend/src/components/AppMap.jsx` → `animateVehicleAlongPath`): a plain
/// `[lng, lat]` path plus a duration, walked at a constant ground rate. It is
/// deliberately a plain value object so the motion is unit-testable without a
/// map, a socket or a widget tree.
class VehicleAnimation {
  const VehicleAnimation({
    required this.vehicleId,
    required this.key,
    required this.path,
    required this.duration,
    this.loop = false,
  });

  final String vehicleId;

  /// Identity of this motion. The map restarts the walk only when the key
  /// changes; a rebuild carrying the same key leaves the in-flight walk
  /// untouched (site parity — `animationRef.animationKey`).
  final String key;

  /// Ordered points to walk. At least two are required to draw anything.
  final List<GeoPoint> path;

  final Duration duration;

  /// Repeat the walk forever. The website loops; ride tracking does not — the
  /// car must settle at the pickup and finish at the destination.
  final bool loop;

  /// The point this walk is heading for (the last usable point).
  GeoPoint? get goal => path.isEmpty ? null : path.last;

  bool get isUsable =>
      vehicleId.isNotEmpty && path.length >= 2 && duration > Duration.zero;

  /// Position + heading at normalised progress [t] (clamped to 0..1).
  AnimatedVehicle? positionAt(double t) => samplePath(path, t);

  /// The path to walk when this animation supersedes [previous], starting from
  /// the vehicle's [current] rendered position.
  ///
  /// Two cases, and the difference matters:
  ///
  /// * **Same goal** (assigned → arriving). The new path's opening point is a
  ///   synthetic offset, not information, so walking it would send the vehicle
  ///   *backwards* to the new offset before approaching again. The vehicle
  ///   instead heads straight for the goal it is already approaching.
  /// * **New goal** (arriving → in transit). The new path's shape is real (the
  ///   road route), so it is kept and merely joined from where the vehicle is.
  ///
  /// Either way the walk continues from the rendered position, so the marker
  /// never teleports and the animation never restarts from the beginning.
  List<GeoPoint> retargetPath({
    required GeoPoint? current,
    required GeoPoint? previousGoal,
  }) {
    final points = _usablePoints(path);
    if (points.length < 2) return points;
    if (current == null) return points;

    final goal = points.last;
    if (!_isFinite(current)) return points;

    final sameGoal =
        previousGoal != null && _planarDistance(previousGoal, goal) <= _sameGoal;
    if (sameGoal) {
      // Degenerate when the vehicle already sits on the goal — keep the path
      // so the walk can still complete rather than collapsing to one point.
      if (_planarDistance(current, goal) <= _degenerate) return points;
      return <GeoPoint>[current, goal];
    }

    if (_planarDistance(current, points.first) <= _atStart) {
      // Already at the start of the new shape — walk it as authored.
      return points;
    }
    return <GeoPoint>[current, ...points];
  }

  /// [duration] rescaled to [effective] so that continuing a walk keeps the
  /// original ground speed instead of restarting the clock.
  Duration scaledDuration(List<GeoPoint> effective) {
    final original = pathLengthMeters(path);
    final remaining = pathLengthMeters(effective);
    if (original <= 0 || remaining <= 0) return duration;

    final share = (remaining / original).clamp(0.0, 4.0);
    final millis = (duration.inMilliseconds * share).round();
    return Duration(
      milliseconds: millis.clamp(_minDurationMs, _maxDurationMs),
    );
  }

  static const double _degenerate = 1e-9;

  /// "The same point" — ~11 cm. Used to tell a genuine goal change from the
  /// same goal being re-sent (assigned → arriving both target the pickup, so
  /// their coordinates are byte-identical from the same ride record).
  static const double _sameGoal = 1e-6;

  /// "The vehicle is already at the start of this path" — ~15 m. Anything
  /// larger is joined from the rendered position so the marker cannot jump.
  static const double _atStart = 1.4e-4;

  static const int _minDurationMs = 700;
  static const int _maxDurationMs = 60000;
}

/// Position + heading at normalised progress [t] (clamped to 0..1) along a bare
/// [path] — the website's `interpolatePath()`.
///
/// Segment lengths are weighted by distance — longitude scaled by `cos(lat)` so
/// a degree of longitude at the equator and one at Bengaluru's latitude are not
/// treated as equal — which is what makes a vehicle cover ground at a constant
/// rate instead of spending equal time on a 5 m and a 500 m segment. Returns
/// null when the path cannot be walked (fewer than two usable points).
AnimatedVehicle? samplePath(List<GeoPoint> path, double t) {
  final points = _usablePoints(path);
  if (points.length < 2) return null;

  final progress = t.isFinite ? t.clamp(0.0, 1.0) : 0.0;

  final segments = <double>[];
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    final length = _planarDistance(points[i - 1], points[i]);
    segments.add(length);
    total += length;
  }

  // Every point collapsed onto one spot: park there, no heading.
  if (total <= VehicleAnimation._degenerate) {
    return AnimatedVehicle(position: points.last);
  }

  var remaining = total * progress;
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (remaining <= segment) {
      final ratio = segment <= VehicleAnimation._degenerate
          ? 0.0
          : remaining / segment;
      return AnimatedVehicle(
        position: _lerp(points[i], points[i + 1], ratio),
        bearingDegrees: segment <= VehicleAnimation._degenerate
            ? null
            : bearingBetween(points[i], points[i + 1]),
      );
    }
    remaining -= segment;
  }
  return AnimatedVehicle(position: points.last);
}

/// Compass bearing from [from] to [to] in degrees, 0..360 (0 = north).
///
/// Port of the website's `bearingBetween()` — the standard great-circle initial
/// bearing, which is what makes the marker point along the road it is driving.
double bearingBetween(GeoPoint from, GeoPoint to) {
  final lat1 = _rad(from.lat);
  final lat2 = _rad(to.lat);
  final dLng = _rad(to.lng - from.lng);

  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  if (y == 0 && x == 0) return 0;

  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Total length of [path] in metres (haversine). Used to keep the vehicle's
/// ground speed stable when a walk is retargeted.
double pathLengthMeters(List<GeoPoint> path) {
  final points = _usablePoints(path);
  if (points.length < 2) return 0;

  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _haversineMeters(points[i - 1], points[i]);
  }
  return total;
}

/// Straight-line metres between two points.
double distanceMeters(GeoPoint a, GeoPoint b) => _haversineMeters(a, b);

const double _earthRadiusMeters = 6371008.8;

double _haversineMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Distance in the flat projection used for interpolation: longitude scaled by
/// `cos(lat)`. Returns "degrees on a locally square grid", which is all the
/// interpolation needs — mixing raw degrees with scaled ones would distort
/// where the midpoints land.
double _planarDistance(GeoPoint a, GeoPoint b) {
  final dx = (b.lng - a.lng) * math.cos(_rad(b.lat));
  final dy = b.lat - a.lat;
  return math.sqrt(dx * dx + dy * dy);
}

GeoPoint _lerp(GeoPoint a, GeoPoint b, double ratio) => GeoPoint(
      a.lat + (b.lat - a.lat) * ratio,
      a.lng + (b.lng - a.lng) * ratio,
    );

/// Drops non-finite points and consecutive duplicates, so a malformed realtime
/// payload can never produce a NaN marker or a division by zero.
List<GeoPoint> _usablePoints(List<GeoPoint> path) {
  final points = <GeoPoint>[];
  for (final point in path) {
    if (!_isFinite(point)) continue;
    if (points.isNotEmpty &&
        _planarDistance(points.last, point) <= VehicleAnimation._degenerate) {
      continue;
    }
    points.add(point);
  }
  return points;
}

bool _isFinite(GeoPoint point) =>
    point.lat.isFinite &&
    point.lng.isFinite &&
    point.lat.abs() <= 90 &&
    point.lng.abs() <= 180;

double _rad(double degrees) => degrees * math.pi / 180;
double _deg(double radians) => radians * 180 / math.pi;
