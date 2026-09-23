// The carpool service's endpoints: the passenger's pickup confirmation and the
// driver's Carpool Run actions. Exercised over an isolated transport so no live
// backend is needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/services/api_client.dart';
import 'package:finalyr_app/services/carpool_service.dart';

void main() {
  // ApiClient resolves the stored token through SharedPreferences.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late CarpoolService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response('{}', 200);
    });
    service = CarpoolService.withClient(
      ApiClient.withHttpClient(client, baseUrl: 'http://test.local'),
    );
  });

  test('the passenger confirms at the assigned pickup stop', () async {
    await service.confirmAtPickupStop(42);
    expect(calls, ['POST /rides/42/confirm-pickup']);
  });

  test('the driver actions hit the carpool route endpoints', () async {
    await service.acceptRoute('route-1-abcd');
    await service.announcePickup('route-1-abcd', 7);
    await service.markArrived('route-1-abcd', 7);
    await service.confirmBoarded('route-1-abcd', 7);
    await service.depart('route-1-abcd');
    await service.confirmDropoff('route-1-abcd', 7);
    await service.completeRoute('route-1-abcd');

    expect(calls, [
      'POST /route/route-1-abcd/accept',
      'POST /route/route-1-abcd/carpool/announce-pickup/7',
      'POST /route/route-1-abcd/carpool/mark-arrived/7',
      'POST /route/route-1-abcd/carpool/confirm-pickup/7',
      'POST /route/route-1-abcd/carpool/depart',
      'POST /route/route-1-abcd/carpool/confirm-dropoff/7',
      'POST /route/route-1-abcd/carpool/complete',
    ]);
  });

  test('a backend refusal surfaces as an ApiException', () async {
    final client = MockClient(
      (request) async => http.Response(
        '{"detail":"Every rider must be dropped off before the run can be completed"}',
        409,
      ),
    );
    final failing = CarpoolService.withClient(
      ApiClient.withHttpClient(client, baseUrl: 'http://test.local'),
    );

    await expectLater(
      failing.completeRoute('route-1-abcd'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', contains('dropped off')),
      ),
    );
  });
}
