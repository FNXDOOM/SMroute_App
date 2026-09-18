import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment_transaction.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Payment screen backed by the existing backend's payment history
/// (`GET /payments/mine`). The backend has NO wallet and NO stored-card
/// endpoints — real payments run through Razorpay Checkout with the amount
/// computed server-side — so those UI blocks are intentionally absent
/// (see README.md).
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadPaymentData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.paper,
          backgroundColor: AppColors.surface,
          onRefresh: () => context.read<PaymentProvider>().loadPaymentData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Payment',
                  description:
                      'Fares are computed server-side and paid via Razorpay '
                      'at checkout.',
                  onBack: () => Navigator.maybePop(context),
                  backLabel: 'Profile',
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Total spent (real records, neutral card) ───────────────
                Consumer<PaymentProvider>(
                  builder: (context, provider, _) {
                    final spent = provider.isLoading &&
                            provider.transactions.isEmpty
                        ? null
                        : provider.totalSpent;
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Total spent on rides'),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            spent == null
                                ? '—'
                                : '₹${spent.toStringAsFixed(2)}',
                            style: AppType.hero.copyWith(fontSize: 36),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionLabel('Payment history'),
                const SizedBox(height: AppSpacing.sm),

                Consumer<PaymentProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading && provider.transactions.isEmpty) {
                      return const SkeletonRows(count: 4, height: 56);
                    }
                    if (provider.error != null &&
                        provider.transactions.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ErrorBanner(message: provider.error!),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: 'Retry',
                            variant: AppButtonVariant.secondary,
                            expand: false,
                            onPressed: provider.loadPaymentData,
                          ),
                        ],
                      );
                    }
                    if (provider.transactions.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No payments yet',
                        hint:
                            'Your ride fares will appear here once you pay for '
                            'a trip.',
                      );
                    }
                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0;
                              i < provider.transactions.length;
                              i++) ...[
                            if (i > 0)
                              const Divider(
                                color: AppColors.border,
                                height: 1,
                                thickness: 1,
                              ),
                            _TransactionRow(tx: provider.transactions[i]),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Transaction row — label + status badge + tabular amount. Credits use the
/// site's blue "completed" tint; debits stay neutral.
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final PaymentTransaction tx;

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final sign = isCredit ? '+' : '−';
    final amount = '$sign₹${tx.amount.abs().toStringAsFixed(2)}';
    final date = tx.createdAt == null
        ? ''
        : ' · ${tx.createdAt!.month}/${tx.createdAt!.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.label,
                  style: AppType.smallStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    StatusBadge(status: tx.status),
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        date.replaceFirst(' · ', ''),
                        style: AppType.caption.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            amount,
            style: AppType.data.copyWith(
              fontSize: 14,
              color: isCredit ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
