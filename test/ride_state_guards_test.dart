// Regression guards for ride-state integrity: a stale status poll must never
// write onto a rebooked ride, and logout must clear the confirmed pickup so one
// account's trip cannot leak into the next.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/providers/ride_provider.dart';
import 'package:finalyr_app/services/api_client.dart';
import 'package:finalyr_app/services/geocoding_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  ApiClient clientReturning(Future<http.Response> Function(http.Request) handler) =>
      ApiClient.withHttpClient(MockClient(handler), baseUrl: 'http://test.local');

  Map<String, dynamic> rideJson(int id, String status) => {
        'id': id,
        'status': status,
        'pickup_lat': 12.9716,
        'pickup_lng': 77.5946,
        'dest_lat': 12.9352,
        'dest_lng': 77.6245,
      };

  test('a status poll never writes a stale ride onto the rebooked one', () async {
    final gate = Completer<void>();
    final client = clientReturning((request) async {
      if (request.url.path == '/rides/44') {
        await gate.future;
        return http.Response(jsonEncode(rideJson(44, 'completed')), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('', 404);
    });
    final provider = RideProvider(api: client);
    provider.debugSetRides(
      [RideRequestRecord.fromJson(rideJson(44, 'arriving'))],
      currentRideId: 44,
    );

    final poll = provider.debugPollStatusOnce();
    // Dismiss + rebook while the old ride's poll is still in flight.
    provider.debugSetRides(
      [RideRequestRecord.fromJson(rideJson(55, 'arriving'))],
      currentRideId: 55,
    );
    gate.complete();
    await poll;

    expect(provider.currentRideId, 55);
    expect(provider.activeRideRecord?.status, 'arriving');
    expect(provider.stage, isNot(BookingStage.completed));
  });

  test('reset clears the confirmed pickup so the next account starts clean', () {
    final provider = RideProvider(
      api: clientReturning((_) async => http.Response('', 404)),
    );
    provider.setPickup(point: const GeoPoint(12.9716, 77.5946), label: 'Home');
    expect(provider.pickupConfirmed, isTrue);

    provider.reset();

    expect(provider.pickupPoint, isNull);
    expect(provider.pickupLabel, 'Current location');
    expect(provider.pickupConfirmed, isFalse);
  });
}