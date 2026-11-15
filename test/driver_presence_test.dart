// Driver presence: the dispatch availability signal. The backend only
// auto-assigns routes to drivers seen within its 90 s presence window, so the
// console must beat POST /auth/driver/presence while it is open (site: 30 s).

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/providers/auth_provider.dart';
import 'package:finalyr_app/providers/driver_provider.dart';
import 'package:finalyr_app/services/api_client.dart';
import 'package:finalyr_app/services/driver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late DriverService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response('{}', 200);
    });
    service = DriverService.withClient(
      ApiClient.withHttpClient(client, baseUrl: 'http://test.local'),
    );
  });

  int presenceBeats() =>
      calls.where((c) => c == 'POST /auth/driver/presence').length;

  test('presence hits POST /auth/driver/presence', () async {
    await service.sendPresence();
    expect(calls, ['POST /auth/driver/presence']);
  });

  test('the console beats on open, every 30 s, and stops when it closes', () {
    fakeAsync((async) {
      final provider = DriverProvider(AuthProvider(), service: service);
      provider.load();
      async.flushMicrotasks();
      expect(presenceBeats(), 1, reason: 'the website beats immediately on mount');

      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(presenceBeats(), 2);

      provider.stopBoardPolling();
      async.elapse(const Duration(seconds: 60));
      async.flushMicrotasks();
      expect(presenceBeats(), 2, reason: 'a closed console must stop beating');
    });
  });
}