// Contract tests: client models must parse the backend's actual response
// shapes (mirrors backend/schemas/*.py). If the backend contract changes,
// these tests catch it.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/models/payment_transaction.dart';
import 'package:finalyr_app/models/user.dart';
import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/models/assigned_vehicle.dart';
import 'package:finalyr_app/models/notification_model.dart';
import 'package:finalyr_app/services/geocoding_service.dart';
import 'package:finalyr_app/services/api_client.dart';

void main() {
  // ApiClient reads the stored token through SharedPreferences.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backend contract: PaymentResponse (GET /payments/mine)', () {
    test('parses paise amount into rupees', () {
      final tx = PaymentTransaction.fromJson({
        'id': 7,
        'user_id': 1,
        'ride_request_id': 42,
        'purpose': 'ride',
        'amount': 1550, // paise
        'currency': 'INR',
        'status': 'paid',
        'razorpay_order_id': 'order_x',
        'razorpay_payment_id': 'pay_y',
        'verified': true,
        'failure_reason': null,
        'created_at': '2026-09-10T10:30:00Z',
        'updated_at': '2026-09-10T10:31:00Z',
      });
      expect(tx.id, 7);
      expect(tx.amount, 15.50);
      expect(tx.status, 'paid');
      expect(tx.isPaid, isTrue);
      expect(tx.isCredit, isFalse);
      expect(tx.label, contains('Ride #42'));
    });

    test('missing id throws (record skipped, not silently zeroed)', () {
      expect(
        () => PaymentTransaction.fromJson({'amount': 100}),
        throwsFormatException,
      );
    });

    test('refunded payment maps to credit kind', () {
      final tx = PaymentTransaction.fromJson({
        'id': 9,
        'amount': 1200,
        'status': 'refunded',
        'purpose': 'ride',
      });
      expect(tx.kind, 'credit');
      expect(tx.status, 'refunded');
    });

    test('wallet top-up purpose gets a readable label', () {
      final tx = PaymentTransaction.fromJson({
        'id': 3,
        'amount': 50000,
        'status': 'paid',
        'purpose': 'wallet_topup',
      });
      expect(tx.label, 'Wallet top-up payment');
    });
  });

  group('Backend contract: TokenResponse (POST /auth/login)', () {
    test('AppUser parses UserResponse shape (snake_case)', () {
      final user = AppUser.fromJson({
        'id': 11,
        'name': 'Gudiya',
        'email': 'g@example.com',
        'phone': '9876543210',
        'role': 'passenger',
        'driver_status': 'active',
        'created_at': '2026-07-22T09:00:00Z',
      });
      expect(user.id, 11);
      expect(user.role, 'passenger');
      expect(user.createdAt, isNotNull);
      expect(user.firstName, 'Gudiya');
    });
  });

  group('Backend contract: RideRequestResponse (POST /rides/request)', () {
    test('parses full ride response', () {
      final ride = RideRequestRecord.fromJson({
        'id': 55,
        'user_id': 11,
        'pickup_lat': 12.9716,
        'pickup_lng': 77.5946,
        'dest_lat': 12.9352,
        'dest_lng': 77.6245,
        'status': 'pending',
        'mode': 'live',
        'h3_index': '8928308280fffff',
        'cluster_id': null,
        'virtual_stop_id': null,
        'request_time': '2026-09-10T10:00:00Z',
        'pickup_label': 'Current location',
        'destination_label': 'MG Road, Bengaluru',
        'ride_option_id': 'swift-x',
        'ride_option_name': 'SwiftX',
        'ride_option_price': '₹12–15',
      });
      expect(ride.id, 55);
      expect(ride.status, 'pending');
      expect(ride.rideOptionId, 'swift-x');
      expect(ride.destinationLabel, 'MG Road, Bengaluru');
    });

    test('missing id throws', () {
      expect(
        () => RideRequestRecord.fromJson({'status': 'pending'}),
        throwsFormatException,
      );
    });
  });

  group('Backend contract: VehicleSnapshot (GET /rides/{id}/vehicle)', () {
    test('parses assigned vehicle', () {
      final v = AssignedVehicle.fromJson({
        'id': 3,
        'license_plate': 'KA-01-AB-1234',
        'status': 'en_route',
        'lat': 12.97,
        'lng': 77.59,
        'assigned_route_id': 'route-1',
      });
      expect(v.id, 3);
      expect(v.licensePlate, 'KA-01-AB-1234');
      expect(v.status, 'en_route');
      expect(v.lat, 12.97);
    });
  });

  group('Backend contract: NotificationListResponse', () {
    test('parses notification and maps ride_status_updated type', () {
      final n = AppNotification.fromJson({
        'id': 21,
        'user_id': 11,
        'notification_type': 'ride_status_updated',
        'title': 'Ride update',
        'message': 'Your ride is arriving',
        'related_entity_type': 'ride_request',
        'related_entity_id': 55,
        'notification_metadata': {'new_status': 'arriving'},
        'is_read': false,
        'read_at': null,
        'created_at': '2026-09-10T10:05:00Z',
      });
      expect(n.id, '21');
      expect(n.type, NotificationType.ride);
      expect(n.read, isFalse);
      expect(n.body, 'Your ride is arriving');
    });
  });

  group('Geocoding service (India service area)', () {
    test('default pickup is Bengaluru, inside the service area', () {
      final p = GeocodingService.defaultPickup;
      expect(p.lat, closeTo(12.97, 0.01));
      expect(p.lng, closeTo(77.59, 0.01));
      expect(p.isInIndiaServiceArea, isTrue);
    });

    test('San Francisco coordinates are rejected as outside the area', () {
      // Regression guard: the old mock geocoder produced SF points, which the
      // backend 422s. Client-side validation must catch them first.
      const sf = GeoPoint(37.7749, -122.4194);
      expect(sf.isInIndiaServiceArea, isFalse);
    });

    test('short queries short-circuit without network calls', () async {
      expect(await GeocodingService.search('a'), isEmpty);
      expect(await GeocodingService.suggest('ab'), isEmpty);
    });
  });

  group('ApiClient error semantics', () {
    test('401/403 are auth failures', () {
      expect(ApiException(401, 'x').isUnauthorized, isTrue);
      expect(ApiException(403, 'x').isUnauthorized, isTrue);
    });

    test('status 0 is a network failure, not a logout', () {
      final e = ApiException(0, 'timed out');
      expect(e.isNetworkFailure, isTrue);
      expect(e.isUnauthorized, isFalse);
    });

    test('429 is rate limiting with optional Retry-After', () {
      final e = ApiException(429, 'rate limited', retryAfterSeconds: 30);
      expect(e.isRateLimited, isTrue);
      expect(e.retryAfterSeconds, 30);
    });

    test('422 is a validation error (outside-India etc.)', () {
      expect(ApiException(422, 'outside India').isValidationError, isTrue);
    });
  });

  // The intermittent "Clerk token has expired" bug: the app stored ONE session
  // JWT and replayed it on every request, so requests succeeded for the first
  // minute after a mint and then 401'd until the next app boot. These tests
  // pin the behaviours that replaced it.
  group('ApiClient token refresh (intermittent 401 recovery)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    ApiClient clientWith(MockClient transport) =>
        ApiClient.withHttpClient(transport, baseUrl: 'http://test.local');

    test('a request carries the CURRENT token, not the one stored at login',
        () async {
      String? sentAuth;
      final client = clientWith(
        MockClient((request) async {
          sentAuth = request.headers['Authorization'];
          return http.Response('{"ok":true}', 200);
        }),
      );
      await client.setToken('expired-clerk-jwt');
      client.setTokenRefresher(() async => 'fresh-clerk-jwt');

      await client.getJson('/auth/me');

      expect(sentAuth, 'Bearer fresh-clerk-jwt');
    });

    test('401 retries exactly ONCE with a newly minted token', () async {
      var calls = 0;
      var mints = 0;
      final client = clientWith(
        MockClient((request) async {
          calls++;
          if (request.headers['Authorization'] == 'Bearer expired') {
            return http.Response('{"detail":"Clerk token has expired"}', 401);
          }
          return http.Response('{"ok":true}', 200);
        }),
      );
      client.setTokenRefresher(() async => ++mints == 1 ? 'expired' : 'fresh');

      final body = await client.getJson('/auth/me');

      expect(calls, 2, reason: 'one attempt plus exactly one retry');
      expect(mints, 2);
      expect(body, <String, dynamic>{'ok': true});
    });

    test('does NOT loop when the refresh returns the same expired token',
        () async {
      var calls = 0;
      final client = clientWith(
        MockClient((request) async {
          calls++;
          return http.Response('{"detail":"Clerk token has expired"}', 401);
        }),
      );
      client.setTokenRefresher(() async => 'same-expired-token');

      await expectLater(
        client.getJson('/auth/me'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(calls, 1, reason: 'retrying an identical token just repeats the 401');
    });

    test('without a refresher, 401 behaviour is unchanged (backend JWT)',
        () async {
      var calls = 0;
      final client = clientWith(
        MockClient((request) async {
          calls++;
          return http.Response('{"detail":"Invalid token"}', 401);
        }),
      );
      await client.setToken('local-jwt');

      await expectLater(client.getJson('/auth/me'), throwsA(isA<ApiException>()));
      expect(calls, 1);
    });

    test('a failed refresh falls back to the stored token (no dropped auth)',
        () async {
      final client = clientWith(
        MockClient((request) async => http.Response('{"ok":true}', 200)),
      );
      await client.setToken('local-jwt');
      client.setTokenRefresher(() async => throw Exception('offline'));

      expect(await client.liveToken(), 'local-jwt');
    });

    test('concurrent requests share ONE mint (no refresh race)', () async {
      var mints = 0;
      final client = clientWith(
        MockClient((request) async => http.Response('{"ok":true}', 200)),
      );
      client.setTokenRefresher(() async {
        mints++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'jwt-$mints';
      });

      await Future.wait(<Future<dynamic>>[
        client.getJson('/rides/my-rides'),
        client.getJson('/notifications/'),
        client.getJson('/payments/mine'),
        client.getJson('/vehicle/'),
      ]);

      expect(mints, 1, reason: 'parallel API calls must not mint concurrently');
    });
  });
}
