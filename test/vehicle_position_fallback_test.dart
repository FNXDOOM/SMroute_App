import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/models/assigned_vehicle.dart';
import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/providers/ride_provider.dart';
import 'package:finalyr_app/services/api_client.dart';

/// Covers the REST position poll that takes over when `/tracking/ws` exhausts
/// its reconnect budget. `/tracking/feed` is driver-only, so the per-ride
/// endpoint is a passenger's only remaining source of vehicle position.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final paths = <String>[];

  RideProvider providerReturning(
    Map<String, dynamic>? payload, {
    int rideId = 44,
  }) {
    paths.clear();
    final client = ApiClient.withHttpClient(
      MockClient((request) async {
        paths.add(request.url.path);
        if (payload == null) return http.Response('', 500);
        return http.Response(jsonEncode(payload), 200,
            headers: {'content-type': 'application/json'});
      }),
      baseUrl: 'http://test.local',
    );
    final provider = RideProvider(api: client);
    provider.debugSetRides(
      [RideRequestRecord.fromJson({'id': rideId, 'status': 'arriving'})],
      currentRideId: rideId,
    );
    provider.debugSetVehicle(AssignedVehicle(
      id: 12,
      licensePlate: 'KA01AB1234',
      status: 'en_route',
      lat: 12.9000,
      lng: 77.6000,
    ));
    return provider;
  }

  Map<String, dynamic> vehicleAt(double lat, double lng) => {
        'id': 12,
        'license_plate': 'KA01AB1234',
        'status': 'en_route',
        'lat': lat,
        'lng': lng,
      };

  test('asks the per-ride endpoint and advances a stalled position', () async {
    final provider = providerReturning(vehicleAt(12.9601, 77.6094));

    await provider.debugPollVehiclePositionFallback();

    expect(paths, ['/rides/44/vehicle']);
    expect(provider.assignedVehicle?.lat, 12.9601);
    expect(provider.assignedVehicle?.lng, 77.6094);
  });

  test('keeps the last known position when the payload is unusable', () async {
    // The backend's vehicle serializer yields id -1 for a malformed row; that
    // must not teleport the car to a stale or null fix.
    final provider = providerReturning({'license_plate': 'KA01AB1234'});

    await provider.debugPollVehiclePositionFallback();

    expect(provider.assignedVehicle?.lat, 12.9000);
    expect(provider.assignedVehicle?.lng, 77.6000);
  });

  test('a transport failure leaves the position untouched and unstuck',
      () async {
    final provider = providerReturning(null);

    await provider.debugPollVehiclePositionFallback();

    expect(provider.assignedVehicle?.lat, 12.9000);
    // The guard is `_isFetchingVehicle`; a thrown request must clear it so the
    // next tick can still fire.
    await provider.debugPollVehiclePositionFallback();
    expect(provider.assignedVehicle?.lat, 12.9000);
  });

  test('sends nothing once the ride id is gone', () async {
    final provider = providerReturning(vehicleAt(12.9601, 77.6094));
    provider.reset();

    await provider.debugPollVehiclePositionFallback();

    expect(paths, isEmpty);
  });
}
