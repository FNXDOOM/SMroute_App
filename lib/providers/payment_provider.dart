import 'package:flutter/foundation.dart';

import '../models/mock_data.dart';
import '../models/payment_card.dart';
import '../models/payment_transaction.dart';
import '../services/api_client.dart';

class PaymentProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  final List<PaymentCard> _cards = [];
  final List<PaymentTransaction> _transactions = [];
  String _walletBalance = '\$0.00';
  bool _isLoading = false;
  String? _error;

  List<PaymentCard> get cards => List.unmodifiable(_cards);
  List<PaymentTransaction> get transactions => List.unmodifiable(_transactions);
  String get walletBalance => _walletBalance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPaymentData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final wallet = await _api.getJson('/payments/wallet');
      final cards = await _api.getJson('/payments/cards');
      final tx = await _api.getJson('/payments/transactions');

      final walletPayload = wallet as Map<String, dynamic>;
      final balance = walletPayload['balance'];
      final parsedBalance = balance is num ? balance.toDouble() : double.tryParse(balance?.toString() ?? '');
      _walletBalance = '\$${(parsedBalance ?? 0.0).toStringAsFixed(2)}';

      _cards
        ..clear()
        ..addAll((cards as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PaymentCard.fromJson));

      _transactions
        ..clear()
        ..addAll((tx as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PaymentTransaction.fromJson));

      if (_cards.isEmpty) {
        _cards.addAll(MockData.cards);
      }
    } catch (error) {
      _cards
        ..clear()
        ..addAll(MockData.cards);
      _transactions.clear();
      _walletBalance = '\$25.00';
      // Only surface an error if the backend actively rejected the request (not 404/unavailable).
      final isUnavailable = error is ApiException && (error.statusCode == 404 || error.statusCode == 0);
      if (!isUnavailable) {
        _error = error is ApiException ? error.message : 'Unable to load payment data.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPrimary(String id) async {
    try {
      await _api.patchJson('/payments/cards/$id/primary');
      for (final card in _cards) {
        card.isPrimary = card.id == id;
      }
      notifyListeners();
    } catch (error) {
      _error = error is ApiException ? error.message : 'Unable to update primary card.';
      notifyListeners();
    }
  }

  Future<void> addCard({
    required String cardNumber,
    required String cardholderName,
    required String expiry,
    required String cvv,
  }) async {
    try {
      final response = await _api.postJson(
        '/payments/cards',
        body: {
          'card_number': cardNumber,
          'cardholder_name': cardholderName,
          'expiry': expiry,
          'cvc': cvv,
        },
      );
      _cards.add(PaymentCard.fromJson(response as Map<String, dynamic>));
      notifyListeners();
    } catch (error) {
      _error = error is ApiException ? error.message : 'Unable to add card.';
      notifyListeners();
    }
  }

  void clear() {
    _cards.clear();
    _transactions.clear();
    _walletBalance = '\$0.00';
    _error = null;
    notifyListeners();
  }
}
