class PaymentCard {
  final String id;
  final String brand;
  final String last4;
  final String expiry;
  final bool isPrimary;

  const PaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiry,
    required this.isPrimary,
  });

  PaymentCard copyWith({bool? isPrimary}) {
    return PaymentCard(
      id: id,
      brand: brand,
      last4: last4,
      expiry: expiry,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    if (rawId.isEmpty || rawId == 'null') {
      throw const FormatException('Payment card missing valid id');
    }
    return PaymentCard(
      id: rawId,
      brand: (json['brand'] ?? 'Card').toString(),
      last4: (json['last4'] ?? '0000').toString(),
      expiry: (json['expiry'] ?? '').toString(),
      isPrimary: json['is_primary'] == true,
    );
  }
}
