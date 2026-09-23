// Pooled (shared) routes: the passenger's `GET /rides/{id}/route` model, the
// driver's `GET /route/history/{id}` plan, the next-stop derivation, the map's
// single-line ⇄ segments toggle and the numbered legs it draws.
//
// The map is pumped with the keyless fallback tile source, so these run
// offline like the rest of the suite.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/models/shared_route.dart';
import 'package:finalyr_app/providers/auth_provider.dart';
import 'package:finalyr_app/providers/driver_provider.dart';
import 'package:finalyr_app/providers/ride_provider.dart';
import 'package:finalyr_app/services/driver_service.dart';
import 'package:finalyr_app/services/geocoding_service.dart';
import 'package:finalyr_app/services/map_tiles.dart';
import 'package:finalyr_app/theme/app_theme.dart';
import 'package:finalyr_app/widgets/live_map.dart';
import 'package:finalyr_app/widgets/ui_kit.dart';

/// The backend's `RideRouteResponse` shape for a three-stop pooled route:
/// one boarding stop and two drop-offs, the first of which is this rider's.
Map<String, dynamic> _routePayload({int legs = 3}) {
  const legGeometries = [
    [[77.6408, 12.9784], [77.6411, 12.974]],
    [[77.6411, 12.974], [77.6066, 12.9756]],
    [[77.6066, 12.9756], [77.6080, 12.9749]],
  ];
  return {
    'route_id': 'route-3-abc12345',
    'vehicle_id': 3,
    'provider': 'stadia',
    'problem': 'pdp',
    'geometry': const [
      [77.6408, 12.9784],
      [77.6411, 12.974],
      [77.6066, 12.9756],
      [77.6080, 12.9749],
    ],
    'legs': [
      for (var index = 0; index < legs; index++)
        {
          'index': index,
          'geometry': legGeometries[index],
          'distance_meters': 1200.0 + index,
          'duration_seconds': 120.0 + index,
          'from_sequence': index,
          'to_sequence': index + 1,
        },
    ],
    'stops': const [
      {
        'sequence': 0,
        'lat': 12.9784,
        'lng': 77.6408,
        'waypoint_type': 'depot',
        'passenger_count': 0,
        'is_mine': false,
      },
      {
        'sequence': 1,
        'lat': 12.9719,
        'lng': 77.6412,
        'waypoint_type': 'pickup',
        'passenger_count': 2,
        'is_mine': true,
      },
      {
        'sequence': 2,
        'lat': 12.9756,
        'lng': 77.6066,
        'waypoint_type': 'destination',
        'passenger_count': 1,
        'is_mine': true,
      },
      {
        'sequence': 3,
        'lat': 12.9749,
        'lng': 77.6080,
        'waypoint_type': 'destination',
        'passenger_count': 1,
        'is_mine': false,
      },
    ],
    'my_pickup_sequence': 1,
    'my_destination_sequence': 2,
    'my_leg_indices': [1],
    'total_distance_meters': 4200.0,
    'estimated_duration_seconds': 480.0,
  };
}

/// The driver's `RoutePlanResponse` for the same pooled route: the plan carries
/// the rides served at each stop, which is what the next-stop callout needs.
Map<String, dynamic> _planPayload({
  List<int> pickupRides = const [11, 12],
  List<int> firstDropRides = const [11],
  List<int> secondDropRides = const [12],
}) => {
  'id': 7,
  'route_id': 'route-3-abc12345',
  'vehicle_id': 3,
  'status': 'solved',
  'depot_lat': 12.9784,
  'depot_lng': 77.6408,
  'total_distance_meters': 4200.0,
  'estimated_duration_seconds': 480.0,
  'problem': 'pdp',
  'geometry': const [
    [77.6408, 12.9784],
    [77.6411, 12.974],
    [77.6066, 12.9756],
    [77.6080, 12.9749],
  ],
  'legs': const [
    {
      'index': 0,
      'geometry': [
        [77.6408, 12.9784],
        [77.6411, 12.974],
      ],
      'distance_meters': 1800.0,
      'duration_seconds': 200.0,
      'begin_shape_index': 0,
      'end_shape_index': 1,
    },
    {
      'index': 1,
      'geometry': [
        [77.6411, 12.974],
        [77.6066, 12.9756],
        [77.6080, 12.9749],
      ],
      'distance_meters': 2400.0,
      'duration_seconds': 280.0,
      'begin_shape_index': 1,
      'end_shape_index': 3,
    },
  ],
  'route_metadata': const {
    'routing_provider': 'stadia',
    'problem': 'pdp',
    'return_to_depot': false,
  },
  'waypoints': [
    {
      'id': 1,
      'sequence': 0,
      'stop_id': 42,
      'lat': 12.9719,
      'lng': 77.6412,
      'waypoint_type': 'pickup',
      'passenger_ids': pickupRides,
    },
    {
      'id': 2,
      'sequence': 1,
      'stop_id': null,
      'lat': 12.9756,
      'lng': 77.6066,
      'waypoint_type': 'destination',
      'passenger_ids': firstDropRides,
    },
    {
      'id': 3,
      'sequence': 2,
      'stop_id': null,
      'lat': 12.9749,
      'lng': 77.6080,
      'waypoint_type': 'destination',
      'passenger_ids': secondDropRides,
    },
  ],
};

int _polylineCount(WidgetTester tester) => tester
    .widgetList<PolylineLayer>(find.byType(PolylineLayer))
    .fold(0, (total, layer) => total + layer.polylines.length);

List<Color> _polylineColors(WidgetTester tester) => tester
    .widgetList<PolylineLayer>(find.byType(PolylineLayer))
    .expand((layer) => layer.polylines)
    .map((polyline) => polyline.color)
    .toList();

Future<void> _pumpMap(
  WidgetTester tester, {
  required SharedRoute route,
  required bool segmentsMode,
  VoidCallback? onToggle,
  int? nextStopSequence,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveMap(
            height: 400,
            attribution: false,
            tileSource: MapTiles.fallback,
            route: route.geometry,
            routeSegments: route.legPoints,
            segmentsMode: segmentsMode,
            routeStops: route.stops,
            mySegmentIndices: route.myLegIndices,
            nextStopSequence: nextStopSequence,
            onToggleSegments: onToggle,
          ),
        ),
      ),
    );

/// Colour of a rendered stop pin's number, or null when it is not on screen.
Color? _stopLabelColor(WidgetTester tester, String label) {
  final text = tester.widgetList<Text>(find.text(label));
  return text.isEmpty ? null : text.first.style?.color;
}

/// A dispatch-board row, in the shape `GET /rides/` returns.
RideRequestRecord _boardRide(int id, String status) =>
    RideRequestRecord.fromJson({
      'id': id,
      'pickup_lat': 12.9719,
      'pickup_lng': 77.6412,
      'dest_lat': 12.9756,
      'dest_lng': 77.6066,
      'status': status,
      'pickup_label': 'Indiranagar 100 Feet Rd',
      'destination_label': 'MG Road Metro',
    });

DriverProvider _driverProvider({String? routeId}) {
  final provider = DriverProvider(AuthProvider());
  addTearDown(provider.dispose);
  if (routeId != null) {
    provider.debugSetBoard(
      const [],
      vehicle: DriverVehicle(
        id: 3,
        licensePlate: 'KA01AB1234',
        capacity: 4,
        status: 'active',
        assignedRouteId: routeId,
        lat: 12.9784,
        lng: 77.6408,
      ),
    );
  }
  return provider;
}

void main() {
  group('SharedRoute.fromJson', () {
    test('parses the pooled route, its legs and its stops', () {
      final route = SharedRoute.fromJson(_routePayload());

      expect(route, isNotNull);
      expect(route!.routeId, 'route-3-abc12345');
      expect(route.vehicleId, 3);
      expect(route.provider, 'stadia');
      expect(route.problem, 'pdp');
      expect(route.geometry.length, 4);
      expect(route.legs.length, 3);
      expect(route.stops.length, 4);
      expect(route.legPoints.length, 3);
      expect(route.legPoints.every((leg) => leg.length == 2), isTrue);
      expect(route.myLegIndices, [1]);
      expect(route.myPickupSequence, 1);
      expect(route.myDestinationSequence, 2);
      expect(route.stops[1].waypointType, 'pickup');
      expect(route.stops[1].isMine, isTrue);
      expect(route.stops[1].passengerCount, 2);
      expect(route.stops[2].isDestination, isTrue);
    });

    test('a single-leg route is not worth a toggle', () {
      final route = SharedRoute.fromJson(_routePayload(legs: 1));

      expect(route, isNotNull);
      expect(route!.isMultiStop, isFalse);
    });

    test('drops malformed legs and stops instead of failing', () {
      final route = SharedRoute.fromJson({
        'route_id': 'route-9',
        'vehicle_id': 9,
        'geometry': const [
          [77.64, 12.97],
          [77.65, 12.98],
        ],
        'legs': [
          {'index': 0, 'geometry': [77.64, 12.97]}, // not a list of pairs
          {'index': 1, 'geometry': <double>[]},
          {
            'index': 2,
            'geometry': const [
              [77.64, 12.97],
              [77.65, 12.98],
            ],
            'distance_meters': 10,
          },
        ],
        'stops': const [
          {'sequence': 0, 'lng': 77.64, 'waypoint_type': 'pickup'}, // no lat
          {'sequence': 1, 'lat': 12.97, 'lng': 77.64, 'waypoint_type': 'destination'},
        ],
        'my_leg_indices': const [2, 'nonsense'],
      });

      expect(route, isNotNull);
      expect(route!.legs.length, 1);
      expect(route.legs.single.index, 2);
      expect(route.stops.length, 1);
      expect(route.stops.single.isDestination, isTrue);
      expect(route.myLegIndices, [2]);
    });

    test('returns null when nothing is drawable', () {
      expect(SharedRoute.fromJson({'geometry': const [], 'legs': const []}), isNull);
      expect(
        SharedRoute.fromJson({
          'geometry': const [
            [77.64, 12.97],
          ],
        }),
        isNull,
      );
    });
  });

  group('RideProvider pooled-route state', () {
    test('the toggle only means something for a multi-leg pooled route', () {
      final provider = RideProvider();
      addTearDown(provider.dispose);

      // Nothing pooled: the control is not offered and toggling is a no-op.
      expect(provider.hasSegmentedRoute, isFalse);
      provider.toggleRouteDisplay();
      expect(provider.routeDisplay, RouteDisplayMode.single);

      provider.debugSetSharedRoute(SharedRoute.fromJson(_routePayload()));
      expect(provider.hasSegmentedRoute, isTrue);
      expect(provider.routeDisplay, RouteDisplayMode.single, reason: 'starts on the rider\'s own line');

      provider.toggleRouteDisplay();
      expect(provider.routeDisplay, RouteDisplayMode.segments);
      provider.toggleRouteDisplay();
      expect(provider.routeDisplay, RouteDisplayMode.single);
    });

    test('dropping the pooled route returns the map to the rider\'s own line', () {
      final provider = RideProvider();
      addTearDown(provider.dispose);

      provider.debugSetSharedRoute(SharedRoute.fromJson(_routePayload()));
      provider.toggleRouteDisplay();
      expect(provider.routeDisplay, RouteDisplayMode.segments);

      provider.dismissActiveRide();

      expect(provider.sharedRoute, isNull);
      expect(provider.hasSegmentedRoute, isFalse);
      expect(provider.routeDisplay, RouteDisplayMode.single);
    });

    test('a single-leg pooled route never offers segments', () {
      final provider = RideProvider();
      addTearDown(provider.dispose);

      provider.debugSetSharedRoute(SharedRoute.fromJson(_routePayload(legs: 1)));
      provider.toggleRouteDisplay();

      expect(provider.hasSegmentedRoute, isFalse);
      expect(provider.routeDisplay, RouteDisplayMode.single);
    });
  });

  group('LiveMap pooled-route rendering', () {
    testWidgets('the toggle appears only when there are several legs',
        (tester) async {
      final single = SharedRoute.fromJson(_routePayload(legs: 1))!;
      await _pumpMap(tester, route: single, segmentsMode: false, onToggle: () {});
      expect(find.text('Route'), findsNothing);

      final pooled = SharedRoute.fromJson(_routePayload())!;
      await _pumpMap(tester, route: pooled, segmentsMode: false, onToggle: () {});
      expect(find.text('Route'), findsOneWidget);

      // Without a callback (a ride with nothing pooled) the control is absent.
      await _pumpMap(tester, route: pooled, segmentsMode: false);
      expect(find.text('Route'), findsNothing);
    });

    testWidgets('segments mode draws every leg and numbers its stops',
        (tester) async {
      final route = SharedRoute.fromJson(_routePayload())!;

      await _pumpMap(tester, route: route, segmentsMode: false, onToggle: () {});
      // One casing + one line for the whole route.
      expect(_polylineCount(tester), 2);
      expect(find.text('1'), findsNothing);

      await _pumpMap(tester, route: route, segmentsMode: true, onToggle: () {});
      // Three legs, each with its own casing and line.
      expect(_polylineCount(tester), 6);
      // Numbered stop pins, in visit order.
      for (final label in ['1', '2', '3', '4']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('the toggle clears the bottom sheet so it stays tappable',
        (tester) async {
      // Regression: on a map-first screen the map's lower edge is covered by the
      // floating sheet. The chip must be anchored above it, or it renders behind
      // the sheet and taps never reach it.
      final route = SharedRoute.fromJson(_routePayload())!;
      var toggles = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapFirstScaffold(
              map: LayoutBuilder(
                builder: (context, constraints) => LiveMap(
                  fullBleed: true,
                  tileSource: MapTiles.fallback,
                  attribution: false,
                  route: route.geometry,
                  routeSegments: route.legPoints,
                  segmentsMode: false,
                  onToggleSegments: () => toggles++,
                  // What the home/live-tracking screens pass: the sheet height.
                  bottomControlsInset: constraints.maxHeight * 0.56,
                ),
              ),
              sheet: AppDraggableSheet(
                initialSize: 0.56,
                builder: (context, controller) => ListView(
                  controller: controller,
                  children: const [SizedBox(height: 600)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Route'));
      await tester.pump();

      expect(toggles, 1,
          reason: 'the chip must sit above the sheet, not hidden behind it');
    });

    testWidgets("the rider's own leg is drawn in the app accent", (tester) async {
      final route = SharedRoute.fromJson(_routePayload())!;

      await _pumpMap(tester, route: route, segmentsMode: true, onToggle: () {});
      final colors = _polylineColors(tester);

      expect(colors.where((color) => color == AppColors.accent).length, 1);
      expect(colors.where((color) => color == AppColors.paper).length, greaterThan(1));
    });
  });

  group('SharedRoute.fromRoutePlanJson (driver route plan)', () {
    test('maps waypoints, legs and the problem onto the map model', () {
      final route = SharedRoute.fromRoutePlanJson(_planPayload());

      expect(route, isNotNull);
      expect(route!.routeId, 'route-3-abc12345');
      expect(route.vehicleId, 3);
      expect(route.provider, 'stadia');
      expect(route.problem, 'pdp');
      expect(route.geometry.length, 4);
      expect(route.isMultiStop, isTrue);
      expect(route.legPoints.length, 2);
      expect(route.stops.map((stop) => stop.sequence), [0, 1, 2]);
      expect(route.stops.first.waypointType, 'pickup');
      expect(route.stops.first.passengerIds, [11, 12]);
      expect(route.stops.first.passengerCount, 2);
      expect(route.stops.last.isDestination, isTrue);
      // No stop "belongs" to the driver, and there is no rider to highlight.
      expect(route.stops.every((stop) => !stop.isMine), isTrue);
      expect(route.myLegIndices, isEmpty);
    });

    test('attributes each leg to the stops it runs between', () {
      final route = SharedRoute.fromRoutePlanJson(_planPayload())!;

      expect(route.legs.length, 2);
      expect(route.legs.first.fromSequence, 0);
      expect(route.legs.first.toSequence, 1);
      expect(route.legs.last.fromSequence, 1);
      expect(route.legs.last.toSequence, 2);
    });

    test('reads geometry from route_metadata when it is not promoted', () {
      final payload = _planPayload();
      payload['route_metadata'] = <String, dynamic>{
        'routing_provider': 'stadia',
        'problem': 'pdp',
        'geometry': payload['geometry'],
        'legs': payload['legs'],
      };
      payload['geometry'] = const [];
      payload['legs'] = const [];

      final route = SharedRoute.fromRoutePlanJson(payload);

      expect(route, isNotNull);
      expect(route!.geometry.length, 4);
      expect(route.legs.length, 2);
      expect(route.stops.length, 3);
    });

    test('sorts waypoints by sequence and skips malformed ones', () {
      final payload = _planPayload();
      payload['waypoints'] = [
        {
          'id': 3,
          'sequence': 2,
          'lat': 12.9749,
          'lng': 77.6080,
          'waypoint_type': 'destination',
          'passenger_ids': [12],
        },
        // No coordinates: nothing to draw or measure.
        {'id': 1, 'sequence': 0, 'lng': 77.6412, 'waypoint_type': 'pickup'},
        {
          'id': 2,
          'sequence': 1,
          'lat': 12.9756,
          'lng': 77.6066,
          'waypoint_type': 'destination',
          'passenger_ids': ['nonsense', 11],
        },
      ];

      final route = SharedRoute.fromRoutePlanJson(payload)!;

      expect(route.stops.map((stop) => stop.sequence), [1, 2]);
      expect(route.stops.first.passengerIds, [11]);
      // Two stops but two legs: no exact alignment, so nothing is attributed.
      expect(route.legs.every((leg) => leg.fromSequence == null), isTrue);
    });

    test('a plan with no road geometry has nothing to draw', () {
      final payload = _planPayload();
      payload['geometry'] = const [];
      payload['legs'] = const [];

      expect(SharedRoute.fromRoutePlanJson(payload), isNull);
    });
  });

  group('next stop to serve', () {
    test('picks the first stop whose rides have not finished', () {
      final route = SharedRoute.fromRoutePlanJson(_planPayload())!;

      final next = route.nextPendingStop(
        finishedRideIds: {11},
        from: const GeoPoint(12.9784, 77.6408),
      );

      expect(next, isNotNull);
      expect(next!.index, 0);
      expect(next.stop.waypointType, 'pickup');
      expect(next.stop.passengerIds, [11, 12]);
      expect(next.distanceMeters, greaterThan(0));
      // 4200 m in 480 s ≈ 8.75 m/s, so a few hundred metres is one minute.
      expect(next.minutes, greaterThanOrEqualTo(1));
    });

    test('skips finished stops and moves on to the next one', () {
      // Ride 11 boards first and is dropped off first; ride 12 boards with it
      // and goes further.
      final route = SharedRoute.fromRoutePlanJson(
        _planPayload(pickupRides: [11], firstDropRides: [11]),
      )!;

      expect(
        route.nextPendingStop(finishedRideIds: {11})!.stop.sequence,
        2,
        reason: "ride 11's stop and drop-off are both done",
      );
      expect(
        route.nextPendingStop(finishedRideIds: {11})!.stop.passengerIds,
        [12],
      );
    });

    test('reports no distance before the vehicle has a position', () {
      final route = SharedRoute.fromRoutePlanJson(_planPayload())!;

      final next = route.nextPendingStop();

      expect(next, isNotNull);
      expect(next!.distanceMeters, isNull);
      expect(next.minutes, isNull);
    });

    test('never sends the driver to the depot, and ends when work is done', () {
      // A pickups-only (cvrp) plan closes back at the hub.
      final payload = _planPayload(pickupRides: [11], firstDropRides: [11]);
      final waypoints = (payload['waypoints'] as List).cast<Object>();
      payload['waypoints'] = [
        ...waypoints.take(2),
        {
          'id': 4,
          'sequence': 2,
          'lat': 12.9784,
          'lng': 77.6408,
          'waypoint_type': 'depot',
          'passenger_ids': const <int>[],
        },
      ];

      final route = SharedRoute.fromRoutePlanJson(payload)!;

      expect(route.stops.last.isDepot, isTrue);
      // Ride 11 still has stops to serve; the hub never becomes the answer.
      expect(route.nextPendingStop()!.stop.sequence, 0);
      // Ride 11 finished → nothing left, and the depot is not "work".
      expect(route.nextPendingStop(finishedRideIds: {11}), isNull);
    });
  });

  group('DriverProvider pooled-route state', () {
    test('a plan with no assignment has nothing to draw', () {
      final driver = _driverProvider();

      expect(driver.assignedRoute, isNull);
      expect(driver.hasSegmentedRoute, isFalse);
      expect(driver.nextStop, isNull);
      expect(driver.pendingStopCount, 0);
    });

    test('the toggle only means something for a multi-leg pooled route', () {
      final driver = _driverProvider();
      driver.debugSetAssignedRoute(
        SharedRoute.fromRoutePlanJson(_planPayload()),
      );

      expect(driver.hasSegmentedRoute, isTrue);
      expect(driver.routeDisplay, RouteDisplayMode.single);

      driver.toggleRouteDisplay();
      expect(driver.routeDisplay, RouteDisplayMode.segments);
      driver.toggleRouteDisplay();
      expect(driver.routeDisplay, RouteDisplayMode.single);

      // A single-leg plan stays one line: toggling does nothing.
      final single = _planPayload();
      final waypoints = (single['waypoints'] as List).cast<Object>();
      single['legs'] = [(single['legs'] as List).first];
      single['waypoints'] = [waypoints.first, waypoints.last];
      driver.debugSetAssignedRoute(SharedRoute.fromRoutePlanJson(single));

      expect(driver.hasSegmentedRoute, isFalse);
      driver.toggleRouteDisplay();
      expect(driver.routeDisplay, RouteDisplayMode.single);
    });

    test('the next stop advances as the board reports rides finished', () {
      final route = SharedRoute.fromRoutePlanJson(
        _planPayload(pickupRides: [11], firstDropRides: [11]),
      )!;
      final driver = _driverProvider(routeId: route.routeId)
        ..debugSetAssignedRoute(route);

      // Both rides are live, so every stop still has work.
      driver.debugSetBoard([_boardRide(11, 'in_progress'), _boardRide(12, 'assigned')]);
      expect(driver.nextStop!.stop.sequence, 0);
      expect(driver.pendingStopCount, 3);

      // Ride 11 finishes: its boarding stop and drop-off are done, so the
      // callout moves to the stop that still has a rider — and it knows how
      // far away the vehicle is.
      driver.debugSetBoard([_boardRide(11, 'completed'), _boardRide(12, 'assigned')]);
      expect(driver.nextStop!.stop.sequence, 2);
      expect(driver.nextStop!.stop.passengerIds, [12]);
      expect(driver.pendingStopCount, 1);
      expect(driver.nextStop!.distanceMeters, greaterThan(0));
      expect(driver.vehiclePoint, isNotNull);

      driver.debugSetBoard([
        _boardRide(11, 'completed'),
        _boardRide(12, 'cancelled'),
      ]);
      expect(driver.nextStop, isNull);
      expect(driver.pendingStopCount, 0);
    });

    testWidgets('the next stop pin is drawn in the accent', (tester) async {
      final route = SharedRoute.fromRoutePlanJson(_planPayload())!;

      await _pumpMap(
        tester,
        route: route,
        segmentsMode: true,
        onToggle: () {},
        nextStopSequence: 1,
      );

      expect(_stopLabelColor(tester, '1'), AppColors.ink);
      expect(_stopLabelColor(tester, '2'), AppColors.paper);
      expect(_stopLabelColor(tester, '3'), AppColors.ink);

      // No callout: every pin keeps the neutral treatment.
      await _pumpMap(tester, route: route, segmentsMode: true, onToggle: () {});
      expect(_stopLabelColor(tester, '2'), AppColors.ink);
    });
  });
}
