/// A payment record from `GET /payments/mine` (backend PaymentResponse
/// schema — backend/schemas/payment.py). Amounts arrive in paise and are
/// exposed in rupees.
class PaymentTransaction {
  final int id;
  final String label;
  final double amount;
  final String kind;
  final DateTime? createdAt;
  final String status;
  final String purpose;

  const PaymentTransaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.kind,
    required this.createdAt,
    this.status = 'paid',
    this.purpose = 'ride',
  });

  /// Backend stores amounts in paise; the UI shows rupees.
  static double _paiseToRupees(num paise) => paise / 100.0;

  /// Human label: backend has no free-text description, so build one from
  /// purpose + ride reference, e.g. "Ride #12 payment".
  static String _labelFrom(Map<String, dynamic> json) {
    final purpose = (json['purpose'] ?? 'ride').toString();
    final rideId = json['ride_request_id'];
    final ridePart = rideId == null ? '' : ' #$rideId';
    final suffix = switch (purpose) {
      'ride' => 'Ride$ridePart',
      'wallet_topup' => 'Wallet top-up',
      _ => purpose,
    };
    return '$suffix payment';
  }

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '');
    if (id == null) {
      throw const FormatException('Payment record missing valid id');
    }
    final rawAmount = json['amount'];
    final paise = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;
    final status = (json['status'] ?? 'pending').toString();
    return PaymentTransaction(
      id: id,
      label: _labelFrom(json),
      amount: _paiseToRupees(paise),
      kind: status == 'refunded' ? 'credit' : 'debit',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      status: status,
      purpose: (json['purpose'] ?? 'ride').toString(),
    );
  }

  /// Credit only when the record is a refund (backend amounts are always
  /// positive paise; direction comes from status/kind, not the sign).
  bool get isCredit => kind == 'credit';

  /// True when the backend marked this payment as captured/verified.
  bool get isPaid => status == 'paid';
}
