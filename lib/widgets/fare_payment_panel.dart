import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ride_provider.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// Shared checkout controls: uncertain payments check server status first.
class FarePaymentPanel extends StatelessWidget {
  const FarePaymentPanel({super.key, required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    final paid = provider.paymentPhase == PaymentPhase.paid;
    final unavailable = provider.fareUnavailableReason;
    final message = provider.paymentError ?? (paid ? null : unavailable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: provider.paymentActionLabel,
          icon: paid
              ? Icons.check_circle_outline
              : provider.paymentNeedsStatusCheck
              ? Icons.refresh
              : Icons.payment_outlined,
          loading: provider.isPaying,
          onPressed:
              provider.isPaying ||
                  paid ||
                  (!provider.paymentNeedsStatusCheck && unavailable != null)
              ? null
              : onPay,
        ),
        if (provider.canResumePayment) ...[
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Resume existing checkout',
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await provider.payActiveRideFare(resumePending: true);
            },
          ),
        ],
        if (message != null) ...[
          const SizedBox(height: AppSpacing.xs),
          ErrorBanner(message: message),
        ],
      ],
    );
  }
}
