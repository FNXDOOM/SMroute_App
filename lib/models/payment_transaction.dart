class PaymentTransaction {
  final int id;
  final String label;
  final double amount;
  final String kind;
  final DateTime? createdAt;

  const PaymentTransaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.kind,
    required this.createdAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: int.tryParse(json['id'].toString()) ?? 0,
      label: (json['label'] ?? json['description'] ?? 'Transaction').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      kind: (json['kind'] ?? 'debit').toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  bool get isCredit => amount >= 0;
}
