import 'package:flutter/foundation.dart';

import '../models/payment_card.dart';
import '../models/payment_transaction.dart';
import '../services/api_client.dart';

class PaymentProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  final List<PaymentCard> _cards = [];
  final List<PaymentTransaction> _transactions = [];
  double _walletBalanceValue = 0.0;
  bool _isLoading = false;
  String? _error;

  List<PaymentCard> get cards => List.unmodifiable(_cards);
  List<PaymentTransaction> get transactions =>
      List.unmodifiable(_transactions);
  double get walletBalanceValue => _walletBalanceValue;
  String get walletBalance => '\$${_walletBalanceValue.toStringAsFixed(2)}';
  bool get isLoading => _isLoading;
  String? get error => _error;

  static double _parseBalance(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0.0;
  }

  Future<void> loadPaymentData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Parallel fetch — one slow endpoint shouldn't triple the wait.
      final results = await Future.wait([
        _api.getJson('/payments/wallet'),
        _api.getJson('/payments/cards'),
        _api.getJson('/payments/transactions'),
      ]);

      final wallet = results[0];
      final cards = results[1];
      final tx = results[2];

      if (wallet is Map<String, dynamic>) {
        _walletBalanceValue = _parseBalance(wallet['balance']);
      }

      if (cards is List) {
        _cards
          ..clear()
          ..addAll(_parseCards(cards));
      }

      if (tx is List) {
        _transactions
          ..clear()
          ..addAll(_parseTransactions(tx));
      }
      // NOTE: no mock fallback here. Showing fake cards/balances as real
      // is worse than showing an empty state + error.
    } catch (error) {
      _error =
          error is ApiException ? error.message : 'Unable to load payment data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<PaymentCard> _parseCards(List<dynamic> raw) {
    final out = <PaymentCard>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        out.add(PaymentCard.fromJson(entry));
      } on FormatException {
        continue;
      }
    }
    return out;
  }

  List<PaymentTransaction> _parseTransactions(List<dynamic> raw) {
    final out = <PaymentTransaction>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        out.add(PaymentTransaction.fromJson(entry));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<void> setPrimary(String id) async {
    try {
      await _api.patchJson('/payments/cards/$id/primary');
      for (var i = 0; i < _cards.length; i++) {
        _cards[i] = _cards[i].copyWith(isPrimary: _cards[i].id == id);
      }
      notifyListeners();
    } catch (error) {
      _error = error is ApiException ? error.message : 'Unable to update primary card.';
      notifyListeners();
    }
  }

  /// Returns null on success, error message otherwise (for form display).
  Future<String?> addCard({
    required String cardNumber,
    required String cardholderName,
    required String expiry,
    required String cvv,
  }) async {
    final validation = validateCardInput(
      cardNumber: cardNumber,
      cardholderName: cardholderName,
      expiry: expiry,
      cvv: cvv,
    );
    if (validation != null) {
      _error = validation;
      notifyListeners();
      return validation;
    }
    try {
      final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
      final response = await _api.postJson(
        '/payments/cards',
        body: {
          'card_number': digits,
          'cardholder_name': cardholderName.trim(),
          'expiry': expiry.trim(),
          'cvc': cvv.trim(),
        },
      );
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Invalid add-card response');
      }
      _cards.add(PaymentCard.fromJson(response));
      _error = null;
      notifyListeners();
      return null;
    } on FormatException {
      _error = 'Unexpected server response.';
      notifyListeners();
      return _error;
    } catch (error) {
      _error = error is ApiException ? error.message : 'Unable to add card.';
      notifyListeners();
      return _error;
    }
  }

  /// Shared client-side validation used by the add-card sheet.
  static String? validateCardInput({
    required String cardNumber,
    required String cardholderName,
    required String expiry,
    required String cvv,
  }) {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 13 || digits.length > 19) {
      return 'Enter a valid card number.';
    }
    if (!_luhnValid(digits)) return 'Enter a valid card number.';
    if (cardholderName.trim().isEmpty) return 'Cardholder name is required.';
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(expiry.trim())) {
      return 'Expiry must be MM/YY.';
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(cvv.trim())) {
      return 'Enter a valid CVV.';
    }
    return null;
  }

  static bool _luhnValid(String digits) {
    var sum = 0;
    var doubleIt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = int.parse(digits[i]);
      if (doubleIt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
  }

  void clear() {
    _cards.clear();
    _transactions.clear();
    _walletBalanceValue = 0.0;
    _error = null;
    notifyListeners();
  }
}
