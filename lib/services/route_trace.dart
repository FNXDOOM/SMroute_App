import 'dart:math' as math;

import '../models/vehicle_animation.dart' show bearingBetween;
import 'geocoding_service.dart' show GeoPoint;

/// A route polyline indexed by cumulative distance, so motion along it can be
/// expressed as "distance travelled" rather than raw positions.
///
/// Port of the website's `routeUtils.buildRoute` (`frontend/src/map/
/// routeUtils.js`): coordinates are cleaned of near-duplicate points, segment
/// lengths are measured with the haversine formula, and [project] maps a raw
/// GPS fix onto the distance along the route it most plausibly belongs to.
class RouteTrace {
  const RouteTrace._(this.coords, this._distances);

  /// Builds the trace, collapsing points closer than [samePointMeters] onto
  /// their predecessor so a degenerate polyline can never divide by zero.
  static RouteTrace build(List<GeoPoint> coords) {
    final clean = <GeoPoint>[];
    for (final point in coords) {
      if (!point.lat.isFinite || !point.lng.isFinite) continue;
      final previous = clean.isEmpty ? null : clean.last;
      if (previous != null && _haversine(previous, point) < _samePointMeters) {
        continue;
      }
      clean.add(point);
    }
    final distances = <double>[0.0];
    for (var i = 1; i < clean.length; i++) {
      distances.add(distances.last + _haversine(clean[i - 1], clean[i]));
    }
    return RouteTrace._(List.unmodifiable(clean), List.unmodifiable(distances));
  }

  /// Points closer than this are the same point for route-building purposes.
  static const double _samePointMeters = 0.01;

  final List<GeoPoint> coords;
  final List<double> _distances;

  /// End-to-end length of the polyline in metres.
  double get length => _distances.isEmpty ? 0.0 : _distances.last;

  bool get isEmpty => coords.length < 2;

  /// The bearing of the segment ending at [index] — used by [pointAtDistance]
  /// so the heading always comes from real road geometry, never interpolated
  /// across a corner.
  double _segmentBearing(int index) {
    if (coords.length < 2) return 0;
    final i = index.clamp(0, coords.length - 2).toInt();
    return bearingBetween(coords[i], coords[i + 1]);
  }

  /// Position and heading at [distance] metres along the route, clamped to the
  /// ends. Segment-relative fractions interpolate position linearly; the
  /// heading is the bearing of the segment the position falls on.
  ({GeoPoint position, double bearing}) pointAtDistance(double distance) {
    if (coords.isEmpty) {
      return (position: const GeoPoint(0, 0), bearing: 0.0);
    }
    if (coords.length == 1) {
      return (position: coords.first, bearing: 0.0);
    }
    final d = distance.clamp(0.0, length);
    var lo = 0;
    var hi = _distances.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_distances[mid] <= d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final start = _distances[lo];
    final end = _distances[hi];
    final span = end - start;
    final t = span <= 0 ? 0.0 : (d - start) / span;
    final a = coords[lo];
    final b = coords[hi];
    return (
      position: GeoPoint(
        a.lat + (b.lat - a.lat) * t,
        a.lng + (b.lng - a.lng) * t,
      ),
      bearing: _segmentBearing(lo),
    );
  }

  /// Distance-along-route of the point on the polyline nearest [point],
  /// restricted to the `[min, max]` window when given.
  ///
  /// [near] breaks ties: when two segments project equally well, the one whose
  /// result sits closest to [near] wins, which keeps a vehicle moving forward
  /// across overlapping roads instead of snapping back.
  double project(GeoPoint point, {double near = 0, double? min, double? max}) {
    if (coords.length < 2) return near;
    final low = min ?? 0.0;
    final high = max ?? length;
    var bestOffset = double.infinity;
    var bestDistance = 0.0;
    var found = false;
    for (var i = 0; i < coords.length - 1; i++) {
      final start = _distances[i];
      final end = _distances[i + 1];
      if (end < low) continue;
      if (start > high) break;
      final a = coords[i];
      final b = coords[i + 1];
      final projected = _projectOntoSegment(point, a, b);
      final candidate = start + projected.t * (end - start);
      final offset = _haversine(point, projected.position);
      final better = offset < bestOffset - 0.01 ||
          (offset <= bestOffset + 0.01 &&
              (candidate - near).abs() < (bestDistance - near).abs());
      if (!found || better) {
        bestOffset = offset;
        bestDistance = candidate;
        found = true;
      }
    }
    if (!found) return near;
    return bestDistance;
  }

  /// Projects [point] onto segment [a]-[b] in a local tangent plane.
  ({double t, GeoPoint position}) _projectOntoSegment(
    GeoPoint point,
    GeoPoint a,
    GeoPoint b,
  ) {
    final scale = math.cos(point.lat * math.pi / 180.0);
    final ax = (a.lng - point.lng) * scale;
    final ay = a.lat - point.lat;
    final bx = (b.lng - point.lng) * scale;
    final by = b.lat - point.lat;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared <= 0) {
      return (t: 0.0, position: a);
    }
    final px = (point.lng - a.lng) * scale;
    final py = point.lat - a.lat;
    final t = ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
    return (
      t: t,
      position: GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t),
    );
  }
}

/// Haversine ground distance in metres.
double _haversine(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  return earthRadius * c;
}

double _rad(double degrees) => degrees * math.pi / 180.0;
