import 'package:flutter_test/flutter_test.dart';

import 'package:finalyr_app/services/geocoding_service.dart';
import 'package:finalyr_app/services/route_trace.dart';

void main() {
  GeoPoint p(double lat, double lng) => GeoPoint(lat, lng);

  group('RouteTrace.build', () {
    test('drops points closer than the dedupe threshold', () {
      final trace = RouteTrace.build([
        p(12.9716, 77.5946),
        p(12.97160, 77.59460), // same point — dropped
        p(12.9716 + 0.001, 77.5946), // ~111 m north — kept
      ]);
      expect(trace.coords.length, 2);
      expect(trace.length, closeTo(111.0, 5.0));
    });

    test('ignores non-finite coordinates', () {
      final trace = RouteTrace.build([
        p(12.9716, 77.5946),
        p(double.nan, 77.6000),
        p(12.9800, 77.6000),
      ]);
      expect(trace.coords.length, 2);
    });

    test('a single point yields an empty (unwalkable) trace', () {
      final trace = RouteTrace.build([p(12.9716, 77.5946)]);
      expect(trace.isEmpty, isTrue);
      expect(trace.length, 0.0);
    });
  });

  group('RouteTrace.project', () {
    // A straight 1 km north-south line at Bengaluru's longitude.
    final trace = RouteTrace.build([
      p(12.9000, 77.6000),
      p(12.9100, 77.6000), // ~1.1 km north
    ]);

    test('a fix on the line projects onto its along-route distance', () {
      final midway = p(12.9050, 77.6000);
      final along = trace.project(midway);
      expect(along, closeTo(555.0, 25.0));
    });

    test('a fix beside the line snaps to the nearest point on it', () {
      // ~40 m east of the line's midpoint — well inside the 65 m snap.
      final beside = p(12.9050, 77.6004);
      final along = trace.project(beside);
      final onRoute = trace.pointAtDistance(along).position;
      expect(onRoute.lat, closeTo(12.9050, 0.0005));
      expect(onRoute.lng, closeTo(77.6000, 0.0005));
    });

    test('a single-point trace returns the query unchanged', () {
      final degenerate = RouteTrace.build([p(12.9000, 77.6000)]);
      expect(degenerate.project(p(12.9050, 77.6000)), 0.0);
    });
  });

  group('RouteTrace.pointAtDistance', () {
    final trace = RouteTrace.build([
      p(12.9000, 77.6000),
      p(12.9100, 77.6000),
      p(12.9100, 77.6100),
    ]);

    test('clamps distances beyond the ends', () {
      expect(trace.pointAtDistance(-5).position.lat, 12.9000);
      expect(
        trace.pointAtDistance(1e9).position.lng,
        closeTo(77.6100, 0.0005),
      );
    });

    test('interpolates between the nearest segments', () {
      final mid = trace.pointAtDistance(trace.length / 2);
      expect(mid.position.lat, allOf(greaterThan(12.9), lessThan(12.91)));
    });
  });
}
