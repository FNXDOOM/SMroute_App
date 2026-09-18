// Ride animation: the pure geometry and the status → path derivation.
//
// These cover the two properties that make the map feel continuous rather than
// teleporting, which are otherwise only observable by watching the map:
//
//  * interpolation walks a path by DISTANCE, so a long road segment is not
//    crossed at the same speed as a short one;
//  * a superseding animation starts from the vehicle's current rendered
//    position, so a status change never restarts the walk or jumps backwards.

import 'package:flutter_test/flutter_test.dart';

import 'package:finalyr_app/models/assigned_vehicle.dart';
import 'package:finalyr_app/models/vehicle_animation.dart';
import 'package:finalyr_app/services/geocoding_service.dart';
import 'package:finalyr_app/services/ride_vehicle_animation.dart';

const _bengaluru = GeoPoint(12.9716, 77.5946);
const _mgRoad = GeoPoint(12.9352, 77.6245);

VehicleAnimation _animation(
  List<GeoPoint> path, {
  String id = 'v1',
  Duration duration = const Duration(seconds: 10),
  bool loop = false,
}) =>
    VehicleAnimation(
      vehicleId: id,
      key: 'k',
      path: path,
      duration: duration,
      loop: loop,
    );

void main() {
  group('samplePath — distance weighted walk', () {
    // A 3-degree east leg then a 1-degree north leg: 4 units total, so the
    // halfway mark is at 2/3 of the FIRST segment, not at the shared corner.
    final path = <GeoPoint>[
      const GeoPoint(0, 0),
      const GeoPoint(0, 3),
      const GeoPoint(1, 3),
    ];

    test('t=0.5 lands inside the long segment, not on the corner', () {
      final sample = samplePath(path, 0.5);
      expect(sample, isNotNull);
      expect(sample!.position.lat, closeTo(0, 1e-9));
      expect(sample.position.lng, closeTo(2, 1e-9));
    });

    test('walks into the second segment only past the corner', () {
      final sample = samplePath(path, 0.875)!;
      expect(sample.position.lat, closeTo(0.5, 1e-9));
      expect(sample.position.lng, closeTo(3, 1e-9));
    });

    test('clamps progress outside 0..1', () {
      expect(samplePath(path, -1)!.position.lng, closeTo(0, 1e-9));
      expect(samplePath(path, 5)!.position.lat, closeTo(1, 1e-9));
    });

    test('reports the heading of the segment being walked', () {
      // East along the first segment, north along the second.
      expect(samplePath(path, 0.25)!.bearingDegrees, closeTo(90, 0.001));
      expect(samplePath(path, 0.95)!.bearingDegrees, closeTo(0, 0.001));
    });

    test('returns null when the path cannot be walked', () {
      expect(samplePath(const [], 0.5), isNull);
      expect(samplePath(const [GeoPoint(1, 1)], 0.5), isNull);
      // Consecutive duplicates collapse to a single usable point.
      expect(samplePath(const [GeoPoint(1, 1), GeoPoint(1, 1)], 0.5), isNull);
    });

    test('drops non-finite and out-of-range points instead of producing NaN',
        () {
      final dirty = <GeoPoint>[
        const GeoPoint(0, 0),
        GeoPoint(double.nan, 0),
        const GeoPoint(0, 3),
        const GeoPoint(999, 0),
      ];
      final sample = samplePath(dirty, 0.5);
      expect(sample, isNotNull);
      expect(sample!.position.lat.isFinite, isTrue);
      expect(sample.position.lng.isFinite, isTrue);
    });
  });

  group('bearingBetween', () {
    test('cardinal directions', () {
      expect(bearingBetween(const GeoPoint(0, 0), const GeoPoint(1, 0)),
          closeTo(0, 0.001)); // north
      expect(bearingBetween(const GeoPoint(0, 0), const GeoPoint(0, 1)),
          closeTo(90, 0.001)); // east
      expect(bearingBetween(const GeoPoint(1, 0), const GeoPoint(0, 0)),
          closeTo(180, 0.001)); // south
      expect(bearingBetween(const GeoPoint(0, 1), const GeoPoint(0, 0)),
          closeTo(270, 0.001)); // west
    });

    test('a degenerate segment has no heading rather than a wrong one', () {
      expect(bearingBetween(_bengaluru, _bengaluru), 0);
    });
  });

  group('retargetPath — continuity across updates', () {
    final pickup = _bengaluru;
    final current = const GeoPoint(12.98, 77.60);
    final approach = <GeoPoint>[
      const GeoPoint(12.9788, 77.6066), // assigned's synthetic start
      pickup,
    ];

    test('same goal: heads for the goal from where the car already is', () {
      // assigned → arriving. The new start offset is nearer the pickup, so
      // walking it as authored would send the car BACKWARDS first.
      final arriving = <GeoPoint>[
        const GeoPoint(12.9740, 77.5986),
        pickup,
      ];
      final path = _animation(arriving)
          .retargetPath(current: current, previousGoal: pickup);

      expect(path.first.lat, closeTo(current.lat, 1e-12));
      expect(path.first.lng, closeTo(current.lng, 1e-12));
      expect(path.last.lat, closeTo(pickup.lat, 1e-12));
      // Never reverses through the intermediate synthetic point.
      expect(path.length, 2);
    });

    test('new goal: keeps the new shape and joins it from the car', () {
      // arriving → in transit. The route's shape is real (roads), so it is
      // preserved and merely entered from the current position.
      final route = <GeoPoint>[
        pickup,
        const GeoPoint(12.96, 77.58),
        const GeoPoint(12.94, 77.60),
      ];
      final path = _animation(route)
          .retargetPath(current: current, previousGoal: pickup);

      expect(path.length, route.length + 1);
      expect(path.first.lat, closeTo(current.lat, 1e-12));
      expect(path[1].lat, closeTo(pickup.lat, 1e-12));
      expect(path.last.lat, closeTo(route.last.lat, 1e-12));
    });

    test('already at the start of the new shape: walks it as authored', () {
      final path = _animation(approach)
          .retargetPath(current: approach.first, previousGoal: pickup);
      expect(path.length, 2);
      expect(path.first.lat, closeTo(approach.first.lat, 1e-12));
    });

    test('no previous position: walks the authored path', () {
      final path = _animation(approach)
          .retargetPath(current: null, previousGoal: null);
      expect(path.length, 2);
      expect(path.first.lat, closeTo(approach.first.lat, 1e-12));
    });
  });

  group('scaledDuration', () {
    test('shrinks in proportion to the distance still to cover', () {
      // ~111 km authored, ~55 km remaining → roughly half the time, so the
      // vehicle keeps its ground speed instead of the clock restarting.
      final animation = _animation(
        const [GeoPoint(0, 0), GeoPoint(1, 0)],
        duration: const Duration(seconds: 20),
      );
      final remaining = animation.scaledDuration(
        const [GeoPoint(0, 0), GeoPoint(0.5, 0)],
      );
      expect(remaining.inMilliseconds, closeTo(10000, 600));
    });

    test('never returns a zero-length or unbounded walk', () {
      final animation = _animation(const [GeoPoint(0, 0), GeoPoint(0, 0)]);
      expect(animation.scaledDuration(const [GeoPoint(0, 0), GeoPoint(0, 0)])
          .inMilliseconds, greaterThan(0));
    });
  });

  group('pathLengthMeters / distanceMeters', () {
    test('measures real ground distance', () {
      // 1 degree of latitude ≈ 111 km.
      expect(distanceMeters(const GeoPoint(0, 0), const GeoPoint(1, 0)),
          closeTo(111195, 500));
      expect(
        pathLengthMeters(const [GeoPoint(0, 0), GeoPoint(1, 0)]),
        closeTo(111195, 500),
      );
    });
  });

  group('RideVehicleAnimation.forRide', () {
    const pickup = _bengaluru;
    const destination = _mgRoad;

    VehicleAnimation? build(
      String status, {
      List<GeoPoint> route = const [],
      AssignedVehicle? vehicle,
      GeoPoint? to = destination,
    }) =>
        RideVehicleAnimation.forRide(
          status: status,
          pickup: pickup,
          destination: to,
          routeGeometry: route,
          vehicle: vehicle,
        );

    test('draws nothing before a driver is assigned', () {
      expect(build('pending'), isNull);
      expect(build('clustered'), isNull);
    });

    test('stops at the end of the ride', () {
      expect(build('completed'), isNull);
      expect(build('cancelled'), isNull);
      expect(build(''), isNull);
      expect(build('something_new'), isNull);
    });

    test('needs a pickup to place anything', () {
      expect(
        RideVehicleAnimation.forRide(
          status: 'assigned',
          pickup: null,
          destination: destination,
        ),
        isNull,
      );
    });

    test('assigned: drives in to the pickup, never past it', () {
      final animation = build('assigned')!;
      expect(animation.vehicleId, RideVehicleAnimation.simulatedVehicleId);
      expect(animation.path.length, 2);
      expect(animation.path.last.lat, closeTo(pickup.lat, 1e-12));
      expect(animation.path.last.lng, closeTo(pickup.lng, 1e-12));
      expect(animation.duration, const Duration(seconds: 25));
      // The synthetic start sits east and slightly north of the pickup.
      expect(animation.path.first.lng, closeTo(pickup.lng + 0.012, 1e-12));
      expect(animation.path.first.lat, closeTo(pickup.lat + 0.0072, 1e-12));
      // Ride tracking must settle, not loop (unlike the website).
      expect(animation.loop, isFalse);
    });

    test('arriving: starts closer in than assigned, over less time', () {
      final assigned = build('assigned')!;
      final arriving = build('arriving')!;
      expect(distanceMeters(arriving.path.first, pickup),
          lessThan(distanceMeters(assigned.path.first, pickup)));
      expect(arriving.duration, const Duration(seconds: 12));
      expect(arriving.path.last.lat, closeTo(pickup.lat, 1e-12));
    });

    test('in transit: follows the road route when the backend gave one', () {
      final route = <GeoPoint>[
        pickup,
        const GeoPoint(12.95, 77.60),
        destination,
      ];
      final animation = build('in_progress', route: route)!;
      expect(animation.path, route);
      expect(animation.duration, const Duration(seconds: 18));
    });

    test('in transit: degrades to a straight line without route geometry', () {
      final animation = build('in_progress')!;
      expect(animation.path.length, 2);
      expect(animation.path.first.lat, closeTo(pickup.lat, 1e-12));
      expect(animation.path.last.lat, closeTo(destination.lat, 1e-12));
    });

    test('in transit: nothing to draw without a destination either', () {
      expect(build('in_progress', to: null), isNull);
    });

    test('a real vehicle position beats the synthetic start point', () {
      final animation = build(
        'assigned',
        vehicle: AssignedVehicle(
          id: 7,
          licensePlate: 'KA01AB1234',
          status: 'active',
          lat: 12.99,
          lng: 77.58,
        ),
      )!;
      expect(animation.vehicleId, '7');
      expect(animation.path.first.lat, closeTo(12.99, 1e-12));
      expect(animation.path.first.lng, closeTo(77.58, 1e-12));
      expect(animation.path.last.lat, closeTo(pickup.lat, 1e-12));
      // Site parity: a known position approaches over 8 s, not 25 s.
      expect(animation.duration, const Duration(seconds: 8));
    });

    test('a vehicle with unusable coordinates falls back to the simulation',
        () {
      final animation = build(
        'assigned',
        vehicle: AssignedVehicle(
          id: 7,
          licensePlate: 'KA01AB1234',
          status: 'active',
          lat: null,
          lng: null,
        ),
      )!;
      expect(animation.vehicleId, RideVehicleAnimation.simulatedVehicleId);
    });

    test('key changes with status so the walk restarts continuously', () {
      expect(build('assigned')!.key, isNot(build('arriving')!.key));
    });

    test('every usable animation satisfies isUsable', () {
      for (final status in const ['assigned', 'arriving', 'in_progress']) {
        final animation = build(status)!;
        expect(animation.isUsable, isTrue, reason: status);
      }
    });
  });
}
