import 'package:flutter/foundation.dart';
import '../models/payment_card.dart';
import '../models/mock_data.dart';

class PaymentProvider extends ChangeNotifier {
  final List<PaymentCard> _cards = MockData.cards;
  final String _walletBalance = '\$25.00';

  List<PaymentCard> get cards => List.unmodifiable(_cards);
  String get walletBalance => _walletBalance;

  void setPrimary(String id) {
    for (final card in _cards) {
      card.isPrimary = card.id == id;
    }
    notifyListeners();
  }

  void addCard(PaymentCard card) {
    _cards.add(card);
    notifyListeners();
  }
}
