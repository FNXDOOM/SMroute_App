// Record and transport integrity: a ride record without usable coordinates is
// rejected (not drawn at (0,0)), and offline transport failures read as network
// ApiExceptions so isNetworkFailure sees them.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/services/api_client.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a ride record without usable coordinates is rejected, not drawn at (0,0)', () {
    expect(
      () => RideRequestRecord.fromJson({'id': 1, 'status': 'pending'}),
      throwsFormatException,
    );
    expect(
      () => RideRequestRecord.fromJson({
        'id': 1,
        'status': 'pending',
        'pickup_lat': 'not-a-number',
        'pickup_lng': 77.5946,
        'dest_lat': 12.9352,
        'dest_lng': 77.6245,
      }),
      throwsFormatException,
    );
    final record = RideRequestRecord.fromJson({
      'id': 1,
      'status': 'pending',
      'pickup_lat': '12.9716',
      'pickup_lng': 77.5946,
      'dest_lat': 12.9352,
      'dest_lng': 77.6245,
    });
    expect(record.pickupLat, 12.9716);
  });

  test('offline transport failures map to a network ApiException', () async {
    final client = ApiClient.withHttpClient(
      MockClient((_) async => throw http.ClientException('Connection failed')),
      baseUrl: 'http://test.local',
    );
    await expectLater(
      client.getJson('/auth/me'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 0)
            .having((e) => e.isNetworkFailure, 'isNetworkFailure', isTrue),
      ),
    );
  });
}