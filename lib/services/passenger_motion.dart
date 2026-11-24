import 'dart:math' as math;

import '../services/geocoding_service.dart' show GeoPoint;
import '../models/vehicle_animation.dart' show distanceMeters;
import 'route_trace.dart';

/// Forward-progress guard for live vehicle fixes, ported from the website's
/// `passengerMotion.js` (`acceptFix` + `routeProgress`).
///
/// The tracker keeps the vehicle's distance along the route monotonic: a fix
/// that would move the marker backwards, or jump it further than
/// [maxJumpMeters] in one step, is rejected rather than drawn. Stale fixes
/// (nothing received for [staleMs]) re-anchor the motion freely, which is what
/// lets a vehicle that teleported — a new driver, a rebroadcast route — jump
/// without animating backwards.
class PassengerMotion {
  PassengerMotion._();

  /// A fix older than this is stale: the next fix re-anchors the motion
  /// instead of being rejected as a regression. The website uses 20 s.
  static const int staleMs = 20000;

  /// Longest single-step jump accepted between consecutive fixes. The website
  /// uses the same 200 m bound in `animatePassengerFix`.
  static const double maxJumpMeters = 200;

  /// Accepts a fix for a vehicle whose previous accepted fix was [previous].
  ///
  /// Returns the fix's timestamp when it may be drawn, or null when it must
  /// not: an out-of-order timestamp, or a jump past [maxJumpMeters] from the
  /// previous position.
  static double? acceptFix({
    required double? previousTimestampSeconds,
    required GeoPoint? previousPosition,
    required GeoPoint position,
    required double? timestampSeconds,
    required DateTime now,
  }) {
    if (position.lat.isNaN || position.lng.isNaN) return null;
    if (previousPosition != null && timestampSeconds != null) {
      final jumped = distanceMeters(previousPosition, position);
      if (jumped > maxJumpMeters &&
          (previousTimestampSeconds == null ||
              timestampSeconds <= previousTimestampSeconds)) {
        return null;
      }
    }
    if (timestampSeconds != null && previousTimestampSeconds != null) {
      if (timestampSeconds <= previousTimestampSeconds) return null;
    }
    return _seconds(now);
  }

  /// Forward-only progress along [trace]: the projected distance of [point],
  /// never behind the previous distance and never more than [maxJumpMeters]
  /// ahead of it. Returns null when the fix lands too far off the route to be
  /// believed (the website's `routeProgress` gate).
  static double? routeProgress(
    RouteTrace trace,
    GeoPoint point,
    double? previous,
  ) {
    final distance = trace.project(point);
    if (previous == null) return distance;
    if (distance < previous - maxJumpMeters) return null;
    if (distance > previous + maxJumpMeters) return null;
    return distance;
  }

  /// Angle interpolation with the website's rate: a full second of frames
  /// closes essentially the whole gap, a single frame closes a fraction of it,
  /// so the marker turns smoothly instead of snapping.
  static double smoothHeading(double from, double to, double dtSeconds) {
    final t = 1 - math.pow(0.85, dtSeconds * 60).toDouble();
    final delta = shortestAngleDelta(from, to);
    return (from + delta * t) % 360;
  }

  /// Shortest signed arc from [from] to [to], in degrees (-180..180).
  static double shortestAngleDelta(double from, double to) {
    return ((to - from + 180) % 360 + 360) % 360 - 180;
  }

  static double _seconds(DateTime now) =>
      now.millisecondsSinceEpoch / Duration.millisecondsPerSecond;
}
