class PaymentCard {
  final String id;
  final String brand;
  final String last4;
  final String expiry;
  bool isPrimary;

  PaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiry,
    required this.isPrimary,
  });
}
