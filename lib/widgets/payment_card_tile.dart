import 'package:flutter/material.dart';
import '../models/payment_card.dart';
import '../theme/app_theme.dart';

class PaymentCardTile extends StatelessWidget {
  final PaymentCard card;
  final VoidCallback? onSetPrimary;

  const PaymentCardTile({super.key, required this.card, this.onSetPrimary});

  String _brandEmoji(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return '💳';
      case 'mastercard':
        return '🔴';
      default:
        return '💳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: card.isPrimary ? AppTheme.accentBlue : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(
            _brandEmoji(card.brand),
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.brand} ···· ${card.last4}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Expires ${card.expiry}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          if (card.isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Primary',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: onSetPrimary,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Set primary',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF555555),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
