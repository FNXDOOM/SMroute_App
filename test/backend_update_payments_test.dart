import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/providers/ride_provider.dart';
import 'package:finalyr_app/services/api_client.dart';
import 'package:finalyr_app/widgets/fare_payment_panel.dart';

RideRequestRecord _ride(int id, {String? tier = 'swift-lux'}) =>
    RideRequestRecord(
      id: id,
      pickupLat: 13,
      pickupLng: 77.6,
      destLat: 13.1,
      destLng: 77.7,
      status: 'completed',
      rideOptionId: tier,
    );

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _order() => {
  'payment_id': 8,
  'razorpay_order_id': 'order_existing',
  'razorpay_key_id': 'rzp_test_only',
  'amount': 4000,
  'currency': 'INR',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'missing stored tier blocks checkout without substituting a selection',
    () async {
      final calls = <String>[];
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          calls.add(request.url.path);
          return _json({'detail': 'not expected'}, 400);
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(api: api);
      addTearDown(provider.dispose);
      provider.debugSetRides([_ride(42, tier: null)], currentRideId: 42);
      expect(await provider.payActiveRideFare(), isFalse);
      expect(calls, isEmpty);
      expect(provider.paymentError, contains('stored fare'));
    },
  );

  test(
    'already-paid 409 reconciles against authoritative payment history',
    () async {
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.method == 'POST') {
            return _json({'detail': 'This ride has already been paid'}, 409);
          }
          return _json([
            {'id': 8, 'ride_request_id': 42, 'status': 'paid', 'verified': 1},
          ]);
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(
        api: api,
        checkout: (_) async => throw StateError('Do not open Checkout'),
      );
      addTearDown(provider.dispose);
      provider.debugSetRides([_ride(42)], currentRideId: 42);
      expect(await provider.payActiveRideFare(), isTrue);
      expect(provider.paymentPhase.name, 'paid');
    },
  );

  test(
    'fare conflict keeps checkout blocked and offers status checks instead',
    () async {
      var creates = 0;
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.method == 'POST') {
            creates++;
            return _json({
              'detail':
                  'Fare changed; reconcile the existing payment before starting another order',
            }, 409);
          }
          return _json([
            {'id': 8, 'ride_request_id': 42, 'status': 'pending'},
          ]);
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(api: api);
      addTearDown(provider.dispose);
      provider.debugSetRides([_ride(42)], currentRideId: 42);
      expect(await provider.payActiveRideFare(), isFalse);
      expect(provider.paymentPhase.name, 'reconciliationRequired');
      await provider.payActiveRideFare();
      expect(creates, 1);
      expect(provider.paymentError, contains('Fare changed'));
    },
  );

  test(
    'verification outage stays pending and later reconciles as paid',
    () async {
      var creates = 0;
      var status = 'pending';
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.method == 'POST') {
            creates++;
            expect(jsonDecode(request.body)['ride_option_id'], 'swift-lux');
            return _json(_order());
          }
          return _json([
            {
              'id': 8,
              'ride_request_id': 42,
              'status': status,
              'verified': status == 'paid' ? 1 : 0,
            },
          ]);
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(
        api: api,
        checkout: (_) async => throw ApiException(502, 'Provider unavailable'),
      );
      addTearDown(provider.dispose);
      provider.debugSetRides([_ride(42)], currentRideId: 42);
      expect(await provider.payActiveRideFare(), isFalse);
      expect(provider.paymentPhase.name, 'pending');
      expect(provider.paymentError, isNot(contains('settle automatically')));
      status = 'paid';
      expect(await provider.payActiveRideFare(), isTrue);
      expect(provider.paymentPhase.name, 'paid');
      expect(creates, 1);
    },
  );

  test('old checkout result cannot mark a different booking paid', () async {
    final result = Completer<bool>();
    final opened = Completer<void>();
    final api = ApiClient.withHttpClient(
      MockClient((request) async => _json(_order())),
      baseUrl: 'http://test.local',
    );
    final provider = RideProvider(
      api: api,
      checkout: (_) {
        opened.complete();
        return result.future;
      },
    );
    addTearDown(provider.dispose);
    provider.debugSetRides([_ride(42)], currentRideId: 42);
    final pending = provider.payActiveRideFare();
    await opened.future;
    provider.reset();
    provider.debugSetRides([_ride(55)], currentRideId: 55);
    result.complete(true);
    expect(await pending, isFalse);
    expect(provider.paymentPhase.name, 'idle');
  });

  test('cancelled booking never starts checkout', () async {
    var requests = 0;
    final api = ApiClient.withHttpClient(
      MockClient((_) async {
        requests++;
        return _json(_order());
      }),
      baseUrl: 'http://test.local',
    );
    final provider = RideProvider(api: api);
    addTearDown(provider.dispose);
    provider.debugSetRides([
      _ride(42).copyWithStatus('cancelled'),
    ], currentRideId: 42);
    expect(await provider.payActiveRideFare(), isFalse);
    expect(requests, 0);
    expect(provider.paymentError, contains('Cancelled'));
  });

  test(
    'payment history for another booking never marks this one paid',
    () async {
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.method == 'POST') return _json(_order());
          return _json([
            {'id': 9, 'ride_request_id': 99, 'status': 'paid'},
          ]);
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(api: api, checkout: (_) async => false);
      addTearDown(provider.dispose);
      provider.debugSetRides([_ride(42)], currentRideId: 42);
      expect(await provider.payActiveRideFare(), isFalse);
      expect(provider.paymentPhase.name, 'pending');
    },
  );

  test(
    'resuming an uncertain checkout is explicit and uses the server order',
    () async {
      var creates = 0;
      var launches = 0;
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.method == 'POST') {
            creates++;
            return _json(_order());
          }
          return _json([
            {'id': 8, 'ride_request_id': 42, 'status': 'pending'},
          ]);
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(
        api: api,
        checkout: (order) async {
          expect(order['razorpay_order_id'], 'order_existing');
          return ++launches == 2;
        },
      );
      addTearDown(provider.dispose);
      provider.debugSetRides([_ride(42)], currentRideId: 42);
      await provider.payActiveRideFare();
      await provider.payActiveRideFare(); // status check, not another checkout
      expect(creates, 1);
      expect(await provider.payActiveRideFare(resumePending: true), isTrue);
      expect(creates, 2);
      expect(launches, 2);
    },
  );

  test('fare conflict cannot be overridden with explicit resume', () async {
    var creates = 0;
    final api = ApiClient.withHttpClient(
      MockClient((request) async {
        if (request.method == 'POST') {
          creates++;
          return _json({
            'detail': 'Fare changed; reconcile the existing payment',
          }, 409);
        }
        return _json([
          {'id': 8, 'ride_request_id': 42, 'status': 'pending'},
        ]);
      }),
      baseUrl: 'http://test.local',
    );
    final provider = RideProvider(api: api);
    addTearDown(provider.dispose);
    provider.debugSetRides([_ride(42)], currentRideId: 42);
    await provider.payActiveRideFare();
    await provider.payActiveRideFare(resumePending: true);
    expect(creates, 1);
    expect(provider.canResumePayment, isFalse);
  });

  test(
    'payment operation remains busy during automatic reconciliation',
    () async {
      final reading = Completer<void>();
      final result = Completer<http.Response>();
      var creates = 0;
      final api = ApiClient.withHttpClient(
        MockClient((request) async {
          if (request.method == 'POST') {
            creates++;
            return _json(_order());
          }
          reading.complete();
          return result.future;
        }),
        baseUrl: 'http://test.local',
      );
      final provider = RideProvider(api: api, checkout: (_) async => false);
      addTearDown(provider.dispose);
      provider.debugSetRides([_ride(42)], currentRideId: 42);
      final payment = provider.payActiveRideFare();
      await reading.future;
      expect(provider.isPaying, isTrue);
      expect(await provider.payActiveRideFare(resumePending: true), isFalse);
      expect(creates, 1);
      result.complete(_json([]));
      await payment;
      expect(provider.isPaying, isFalse);
    },
  );

  testWidgets('pending payment offers status check and explicit resume', (
    tester,
  ) async {
    final api = ApiClient.withHttpClient(
      MockClient(
        (request) async => request.method == 'POST'
            ? _json(_order())
            : _json([
                {'id': 8, 'ride_request_id': 42, 'status': 'pending'},
              ]),
      ),
      baseUrl: 'http://test.local',
    );
    final provider = RideProvider(api: api, checkout: (_) async => false);
    addTearDown(provider.dispose);
    provider.debugSetRides([_ride(42)], currentRideId: 42);
    await provider.payActiveRideFare();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: FarePaymentPanel(onPay: () {})),
        ),
      ),
    );
    expect(find.text('Check payment status'), findsOneWidget);
    expect(find.text('Resume existing checkout'), findsOneWidget);
    expect(find.textContaining('settle automatically'), findsNothing);
  });
}
