import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/models/shared_route.dart';
import 'package:finalyr_app/providers/auth_provider.dart';
import 'package:finalyr_app/providers/driver_provider.dart';
import 'package:finalyr_app/providers/ride_provider.dart';
import 'package:finalyr_app/services/api_client.dart';
import 'package:finalyr_app/services/driver_service.dart';
import 'package:finalyr_app/widgets/carpool_passenger_panel.dart';

Map<String, dynamic> _ride() => {
  'id': 42,
  'status': 'in_progress',
  'carpool_status': 'in_transit',
  'pickup_lat': 13.0,
  'pickup_lng': 77.6,
  'dest_lat': 13.1,
  'dest_lng': 77.7,
  'virtual_stop_id': 7,
  'is_shared': true,
};

Map<String, dynamic> _route(String status) => {
  'route_id': 'route-1',
  'vehicle_id': 10,
  'route_status': status,
  'driver_accepted': true,
  'problem': 'pdp',
  'geometry': [
    [77.6, 13.0],
    [77.7, 13.1],
  ],
  'stops': [],
};

http.Response _json(Object? body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'passenger status poll refreshes a changed route with the same ID',
    () async {
      var routeReads = 0;
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.url.path == '/rides/42/route') {
            routeReads++;
            return _json(_route('needs_reoptimization'));
          }
          if (request.url.path == '/rides/42') return _json(_ride());
          return _json(null);
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(api: api);
      addTearDown(provider.dispose);
      provider.debugSetRides([
        RideRequestRecord.fromJson(_ride()),
      ], currentRideId: 42);
      provider.debugSetSharedRoute(SharedRoute.fromJson(_route('solved')));
      await provider.debugPollStatusOnce();
      expect(routeReads, 1);
      expect(provider.sharedRoute?.routeStatus, 'needs_reoptimization');
      expect(provider.activeRideRecord?.carpoolStatus, 'in_transit');
      expect(
        provider.vehicleAnimation,
        isNull,
        reason:
            'Do not animate a passenger along a route awaiting recalculation',
      );
    },
  );

  test(
    'driver reload refreshes route metadata without an assignment change',
    () async {
      var routeReads = 0;
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.url.path == '/vehicle/') {
            return _json([
              {
                'id': 10,
                'license_plate': 'QA-ONLY',
                'capacity': 3,
                'status': 'active',
                'assigned_route_id': 'route-1',
              },
            ]);
          }
          if (request.url.path == '/rides/') return _json([]);
          if (request.url.path == '/route/history/route-1') {
            routeReads++;
            return _json({
              ..._route('solved'),
              'status': routeReads == 1 ? 'solved' : 'needs_reoptimization',
              'route_metadata': {'carpool_run': true, 'driver_accepted': true},
              'waypoints': [],
            });
          }
          return _json({});
        }),
        baseUrl: 'http://test.local',
      );
      final auth = AuthProvider();
      final provider = DriverProvider(
        auth,
        service: DriverService.withClient(api),
      );
      provider.debugSetBoard(
        [],
        vehicle: const DriverVehicle(
          id: 10,
          licensePlate: 'QA-ONLY',
          capacity: 3,
          status: 'active',
          assignedRouteId: 'route-1',
        ),
      );
      addTearDown(() {
        provider.dispose();
        auth.dispose();
      });
      await provider.load();
      await provider.load();
      expect(routeReads, 2);
      expect(provider.assignedRoute?.routeStatus, 'needs_reoptimization');
      expect(provider.nextStop, isNull);
    },
  );

  testWidgets('passenger sees a warning for a route awaiting recalculation', (
    tester,
  ) async {
    final provider = RideProvider();
    addTearDown(provider.dispose);
    provider.debugSetRides([
      RideRequestRecord.fromJson(_ride()),
    ], currentRideId: 42);
    provider.debugSetSharedRoute(
      SharedRoute.fromJson(_route('needs_reoptimization')),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: CarpoolPassengerPanel())),
      ),
    );
    expect(find.textContaining('Route update pending'), findsOneWidget);
  });

  test(
    'pending route retains its record but exposes no navigation geometry',
    () {
      final route = SharedRoute.fromJson(_route('needs_reoptimization'))!;
      expect(route.geometry, isNotEmpty);
      expect(route.navigationGeometry, isEmpty);
      expect(route.navigationLegPoints, isEmpty);
    },
  );

  test(
    'driver route status is parsed even when road geometry is unavailable',
    () {
      final route = SharedRoute.fromRoutePlanJson({
        'route_id': 'route-1',
        'vehicle_id': 10,
        'status': 'needs_reoptimization',
        'geometry': [],
        'legs': [],
        'waypoints': [],
        'route_metadata': {'carpool_run': true, 'driver_accepted': true},
      });
      expect(route, isNotNull);
      expect(route!.needsReoptimization, isTrue);
    },
  );

  test(
    'passenger pending metadata is retained when geometry is unavailable',
    () {
      final route = SharedRoute.fromJson({
        ..._route('needs_reoptimization'),
        'geometry': [],
        'legs': [],
      });
      expect(route, isNotNull);
      expect(route!.needsReoptimization, isTrue);
      expect(route.navigationGeometry, isEmpty);
    },
  );
}
