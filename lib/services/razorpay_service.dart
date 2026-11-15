import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'api_client.dart';

/// Razorpay Checkout for the app — the mobile twin of the website's
/// `RazorpayPayment` flow:
///
///   1. `POST /payments/create-order` (amount computed server-side; response
///      carries only PUBLIC values: key id, order id, amount, customer info)
///   2. open Razorpay Checkout (native sheet on Android/iOS)
///   3. `POST /payments/verify` with the checkout result — success is shown
///      ONLY after the backend confirms the signature (verified=true).
///
/// The Razorpay Key Secret never reaches this client; there is nothing to
/// configure in the app — the key id arrives from the backend response.
class RazorpayService {
  RazorpayService._();

  static final Razorpay _razorpay = Razorpay();
  static Completer<bool>? _completer;

  /// Opens Checkout for a created order and verifies the result with the
  /// backend. Returns true only when `/payments/verify` says verified=true.
  ///
  /// [checkout] is the `POST /payments/create-order` response.
  static Future<bool> pay({required Map<String, dynamic> checkout}) async {
    final keyId = checkout['razorpay_key_id']?.toString() ?? '';
    final orderId = checkout['razorpay_order_id']?.toString() ?? '';
    final rawAmount = checkout['amount'];
    final amount = rawAmount is int
        ? rawAmount
        : int.tryParse('$rawAmount');
    if (keyId.isEmpty ||
        orderId.isEmpty ||
        amount == null ||
        amount <= 0) {
      throw ApiException(
        0,
        'Payment order is incomplete — cannot start checkout.',
      );
    }

    _cancelPendingCheckout();
    final completer = Completer<bool>();
    _completer = completer;

    final prefill = <String, String?>{
      'name': checkout['customer_name']?.toString(),
      'email': checkout['customer_email']?.toString(),
      'contact': checkout['customer_phone']?.toString(),
    }..removeWhere((_, value) => value == null || value.isEmpty);

    final options = <String, Object?>{
      'key': keyId,
      'order_id': orderId,
      'amount': amount,
      'currency': checkout['currency']?.toString() ?? 'INR',
      'name': 'Smroute',
      'description': 'Ride fare',
      'theme.color': '#000000',
      if (prefill.isNotEmpty) 'prefill': prefill,
    };

    try {
      _razorpay
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
      _razorpay.open(options);
    } on Exception {
      _completer = null;
      throw ApiException(0, 'Could not open the payment sheet.');
    }
    return completer.future;
  }

  static void _onPaymentSuccess(PaymentSuccessResponse response) {
    final completer = _completer;
    _completer = null;
    if (completer == null || completer.isCompleted) return;
    // Backend verification decides success — the plugin event alone is NOT
    // success (same rule as the website).
    unawaited(() async {
      try {
        final result = await ApiClient.instance.postJson(
          '/payments/verify',
          body: <String, dynamic>{
            'razorpay_order_id': response.orderId,
            'razorpay_payment_id': response.paymentId,
            'razorpay_signature': response.signature,
          },
        );
        final verified =
            result is Map<String, dynamic> && result['verified'] == true;
        completer.complete(verified);
      } on ApiException catch (error) {
        completer.completeError(
          ApiException(
            error.statusCode,
            error.statusCode == 0
                ? 'Could not reach the backend to verify the payment.'
                : (error.message.isEmpty
                    ? 'Payment verification failed.'
                    : error.message),
            retryAfterSeconds: error.retryAfterSeconds,
          ),
        );
      } on Exception {
        completer.completeError(
          ApiException(0, 'Payment verification failed.'),
        );
      }
    }());
  }

  static void _onPaymentError(PaymentFailureResponse response) {
    final completer = _completer;
    _completer = null;
    if (completer == null || completer.isCompleted) return;
    final message = response.message;
    completer.completeError(
      ApiException(
        0,
        message == null || message.isEmpty
            ? 'Payment was not completed.'
            : message,
      ),
    );
  }

  static void _onExternalWallet(ExternalWalletResponse response) {
    // Informational only — the actual capture still ends in the success
    // event, which drives verification.
  }

  /// Clears any pending checkout state (logout / ride reset), completing its
  /// future with a failure so the caller never awaits a dropped checkout.
  static void reset() {
    _cancelPendingCheckout();
  }

  static void _cancelPendingCheckout() {
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(ApiException(0, 'Checkout was cancelled.'));
    }
  }
}
