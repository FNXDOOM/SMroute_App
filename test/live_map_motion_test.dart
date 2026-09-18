// The map's vehicle-motion engine: the behaviours that can only be observed
// over time — that a car arriving in a new location is *tweened*, that a new
// ride status continues the walk instead of restarting it, and that the car
// settles at its destination rather than looping.
//
// These drive the real widget tree (ticker included) by advancing the test
// clock, so they cover the wiring between the ride-derived animation and the
// rendered marker, not just the geometry.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finalyr_app/models/vehicle_animation.dart';
import 'package:finalyr_app/services/geocoding_service.dart';
import 'package:finalyr_app/services/map_tiles.dart';
import 'package:finalyr_app/widgets/live_map.dart';

/// A point ~1.3 km out from the pickup, i.e. what `assigned` synthesises.
const _pickup = GeoPoint(12.9716, 77.5946);
const _approachStart = GeoPoint(12.9788, 77.6066);

/// A point ~450 m out, i.e. what `arriving` synthesises — deliberately
/// *behind* [_approachStart], so a restart would send the car backwards.
const _closerStart = GeoPoint(12.9740, 77.5986);

/// The rendered position of the map's vehicle marker.
GeoPoint _rendered(WidgetTester tester) {
  final layers =
      tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).toList();
  expect(layers, isNotEmpty, reason: 'no marker layer on the map');
  final markers = layers.last.markers;
  expect(markers, isNotEmpty, reason: 'no vehicle marker rendered');
  final point = markers.first.point;
  return GeoPoint(point.latitude, point.longitude);
}

Future<void> _pumpMap(
  WidgetTester tester, {
  VehicleAnimation? animation,
  List<MapVehicle> vehicles = const [],
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveMap(
            height: 400,
            attribution: false,
            tileSource: MapTiles.fallback,
            pickup: _pickup,
            vehicles: vehicles,
            vehicleAnimation: animation,
          ),
        ),
      ),
    );

VehicleAnimation _walk(List<GeoPoint> path, {String key = 'k1'}) =>
    VehicleAnimation(
      vehicleId: 'sim-driver',
      key: key,
      path: path,
      duration: const Duration(seconds: 4),
    );

void main() {
  testWidgets('a new ride animation paints the car without animating it in',
      (tester) async {
    await _pumpMap(tester, animation: _walk(const [_approachStart, _pickup]));
    await tester.pump();

    // First paint is the backend's state, not a glide from somewhere else.
    final start = _rendered(tester);
    expect(start.lat, closeTo(_approachStart.lat, 1e-6));
    expect(start.lng, closeTo(_approachStart.lng, 1e-6));
  });

  testWidgets('the car walks continuously toward the pickup and settles there',
      (tester) async {
    await _pumpMap(tester, animation: _walk(const [_approachStart, _pickup]));
    await tester.pump();

    double remaining() => distanceMeters(_rendered(tester), _pickup);

    final distances = <double>[remaining()];
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 800));
      distances.add(remaining());
    }

    // Monotonic: it approaches, it never backs up or teleports.
    for (var i = 1; i < distances.length; i++) {
      expect(distances[i], lessThan(distances[i - 1]),
          reason: 'step $i went backwards ($distances)');
    }

    // Past the end of the 4 s walk the car is parked on the pickup…
    await tester.pump(const Duration(seconds: 3));
    expect(remaining(), lessThan(1));

    // …and stays there (ride tracking settles; the website would loop).
    await tester.pump(const Duration(seconds: 5));
    expect(remaining(), lessThan(1));
  });

  testWidgets('a status change continues the walk instead of restarting it',
      (tester) async {
    await _pumpMap(tester, animation: _walk(const [_approachStart, _pickup]));
    await tester.pump();

    // Mid-approach: the car is well inside the first leg.
    await tester.pump(const Duration(seconds: 2));
    final before = _rendered(tester);
    final travelled = distanceMeters(_approachStart, before);
    expect(travelled, greaterThan(100));

    // Backend flips assigned → arriving. Arriving's synthetic start is CLOSER
    // to the pickup, so replaying its path as authored would jump backwards.
    await _pumpMap(
      tester,
      animation: _walk(const [_closerStart, _pickup], key: 'k2'),
    );
    await tester.pump();

    // The car stays where it was drawn — no jump back to _closerStart…
    final after = _rendered(tester);
    expect(distanceMeters(before, after), lessThan(1));
    expect(distanceMeters(after, _closerStart), greaterThan(100));

    // …and carries on toward the pickup from there.
    final beforeGap = distanceMeters(after, _pickup);
    await tester.pump(const Duration(seconds: 1));
    expect(distanceMeters(_rendered(tester), _pickup), lessThan(beforeGap));
  });

  testWidgets('a discrete GPS update eases the car instead of teleporting it',
      (tester) async {
    const first = MapVehicle(id: '7', lat: 12.99, lng: 77.60);
    const second = MapVehicle(id: '7', lat: 12.975, lng: 77.585);

    await _pumpMap(tester, vehicles: const [first]);
    await tester.pump();
    expect(_rendered(tester).lat, closeTo(first.lat, 1e-6));

    // A real fix arrives from `/tracking/ws` or the 4 s poll.
    await _pumpMap(tester, vehicles: const [second]);
    await tester.pump();

    // Still on the old coordinate on the frame the update lands…
    final onUpdate = _rendered(tester);
    expect(onUpdate.lat, closeTo(first.lat, 1e-6));

    // …part way through the 1200 ms ease it is between the two points…
    await tester.pump(const Duration(milliseconds: 600));
    final midway = _rendered(tester);
    expect(midway.lat, lessThan(first.lat));
    expect(midway.lat, greaterThan(second.lat));

    // …and by the end of the ease it has arrived.
    await tester.pump(const Duration(milliseconds: 800));
    final settled = _rendered(tester);
    expect(settled.lat, closeTo(second.lat, 1e-6));
    expect(settled.lng, closeTo(second.lng, 1e-6));
  });

  testWidgets('a retarget mid-flight continues from the drawn position',
      (tester) async {
    const first = MapVehicle(id: '7', lat: 12.99, lng: 77.60);
    const second = MapVehicle(id: '7', lat: 12.975, lng: 77.585);
    const third = MapVehicle(id: '7', lat: 12.982, lng: 77.593);

    await _pumpMap(tester, vehicles: const [first]);
    await tester.pump();

    await _pumpMap(tester, vehicles: const [second]);
    await tester.pump(const Duration(milliseconds: 600));
    final midway = _rendered(tester);

    // A second fix lands while the first is still easing.
    await _pumpMap(tester, vehicles: const [third]);
    await tester.pump();

    // It restarts from where the car is drawn, not from `first`.
    final retargeted = _rendered(tester);
    expect(distanceMeters(midway, retargeted), lessThan(1));

    await tester.pump(const Duration(milliseconds: 1400));
    final settled = _rendered(tester);
    expect(settled.lat, closeTo(third.lat, 1e-6));
  });

  testWidgets('finishing the ride stops the car at the end of its path',
      (tester) async {
    await _pumpMap(tester, animation: _walk(const [_pickup, _approachStart]));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The ride completes mid-walk: the animation is withdrawn.
    await _pumpMap(tester);
    await tester.pump();

    // The car is not frozen where it happened to be — it runs the path out…
    await tester.pump(const Duration(seconds: 4));
    final parked = _rendered(tester);
    expect(distanceMeters(parked, _approachStart), lessThan(1));

    // …then stops for good.
    await tester.pump(const Duration(seconds: 5));
    expect(distanceMeters(_rendered(tester), parked), lessThan(0.5));
  });

  testWidgets('a malformed animation renders nothing instead of throwing',
      (tester) async {
    await _pumpMap(
      tester,
      animation: _walk(const [_pickup, GeoPoint(double.nan, double.nan)]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a retired car is not deleted mid-glide by an unrelated rebuild',
      (tester) async {
    await _pumpMap(tester, animation: _walk(const [_pickup, _approachStart]));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The ride completes: the animation is withdrawn and the car is no longer
    // in `vehicles`, so nothing owns it any more.
    await _pumpMap(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // An unrelated rebuild lands while the car is still running its path out
    // (a provider notification, a parent setState, …). It must not be swept up
    // as "no longer present" — that would make the car vanish mid-move.
    await _pumpMap(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MarkerLayer), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 5));
    expect(distanceMeters(_rendered(tester), _approachStart), lessThan(1));
  });
}
