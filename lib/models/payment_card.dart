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

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    return PaymentCard(
      id: json['id'].toString(),
      brand: (json['brand'] ?? 'Card').toString(),
      last4: (json['last4'] ?? '0000').toString(),
      expiry: (json['expiry'] ?? '').toString(),
      isPrimary: json['is_primary'] == true,
    );
  }
}
