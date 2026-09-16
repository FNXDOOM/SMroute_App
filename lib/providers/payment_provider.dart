import 'package:flutter/foundation.dart';

import '../models/payment_transaction.dart';
import '../services/api_client.dart';

/// Payment data backed by the existing backend.
///
/// The backend exposes NO wallet and NO stored-cards endpoints — payments run
/// through Razorpay Checkout (create-order → checkout → verify). This
/// provider therefore loads only real payment history via `GET /payments/mine`
/// and never invents balances or cards (no mock fallback by design).
class PaymentProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  final List<PaymentTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<PaymentTransaction> get transactions =>
      List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Total rupees actually paid for rides (captures + completed checkouts).
  double get totalSpent => _transactions
      .where((t) => t.isPaid && t.purpose == 'ride')
      .fold(0.0, (sum, t) => sum + t.amount);

  Future<void> loadPaymentData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getJson('/payments/mine');
      final raw = response is List ? response : const [];
      final items = <PaymentTransaction>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          items.add(PaymentTransaction.fromJson(entry));
        } on FormatException {
          continue; // skip malformed records
        }
      }
      _transactions
        ..clear()
        ..addAll(items);
      // NOTE: no mock fallback. A failing/unconfigured backend surfaces as an
      // error or empty state — never as fake money.
    } catch (error) {
      _error =
          error is ApiException ? error.message : 'Unable to load payments.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _transactions.clear();
    _error = null;
    notifyListeners();
  }
}
