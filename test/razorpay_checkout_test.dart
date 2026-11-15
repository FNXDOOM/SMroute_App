// Checkout integrity: a dropped checkout (logout / ride reset) must settle its
// future instead of hanging forever, and the external-wallet event handler must
// accept the response type the plugin actually delivers.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalyr_app/services/api_client.dart';
import 'package:finalyr_app/services/razorpay_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('reset completes a pending checkout instead of hanging forever', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('razorpay_flutter');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'open') {
        // External-wallet event: informational only, the checkout stays open.
        return <String, dynamic>{
          'type': 2,
          'data': <String, dynamic>{'wallet_name': 'mock'},
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      RazorpayService.reset();
    });

    final future = RazorpayService.pay(checkout: <String, dynamic>{
      'razorpay_key_id': 'rzp_test_mock',
      'razorpay_order_id': 'order_mock',
      'amount': 1500,
      'currency': 'INR',
    });
    var settled = false;
    unawaited(future.then((_) => settled = true, onError: (_) => settled = true));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(settled, isFalse, reason: 'checkout must still be pending before reset');

    RazorpayService.reset();
    await expectLater(future, throwsA(isA<ApiException>()));
  });
}