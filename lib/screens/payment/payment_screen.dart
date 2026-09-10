import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/payment_transaction.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payment_card_tile.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _promoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadPaymentData();
    });
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _showAddCardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => _AddCardSheet(
        onClose: () => Navigator.pop(sheetCtx),
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)),
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/profile'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Text(
                      'Payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.accentBlue,
                backgroundColor: AppTheme.surfaceColor,
                onRefresh: () =>
                    context.read<PaymentProvider>().loadPaymentData(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // a. Wallet card
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accentBlue, AppTheme.accentPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SmartRoute Wallet',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Consumer<PaymentProvider>(
                              builder: (context, provider, _) => Text(
                                provider.walletBalance,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: TextButton(
                                      onPressed: () =>
                                          _comingSoon('Add funds'),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'Add funds',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 36,
                                    child: TextButton(
                                      onPressed: () =>
                                          _comingSoon('Withdraw'),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'Withdraw',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // b. Section label
                      const Text('PAYMENT METHODS',
                          style: AppTheme.labelUppercase),
                      const SizedBox(height: 12),

                      // c. Card list (real backend data, never mock fallback)
                      Consumer<PaymentProvider>(
                        builder: (context, provider, _) {
                          if (provider.isLoading && provider.cards.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.accentBlue),
                              ),
                            );
                          }
                          if (provider.error != null &&
                              provider.cards.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                provider.error!,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF888888)),
                              ),
                            );
                          }
                          if (provider.cards.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF2A2A2A)),
                              ),
                              child: const Text(
                                'No payment methods yet. Add a card below.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888)),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (int i = 0;
                                  i < provider.cards.length;
                                  i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                PaymentCardTile(
                                  card: provider.cards[i],
                                  onSetPrimary: () => context
                                      .read<PaymentProvider>()
                                      .setPrimary(provider.cards[i].id),
                                ),
                              ],
                            ],
                          );
                        },
                      ),

                      // d. Add payment method button
                      GestureDetector(
                        onTap: () {
                          _showAddCardSheet(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF2A2A2A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Add payment method',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF888888),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // e. Promo code section
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Promo code',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _promoController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter code',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final code =
                                        _promoController.text.trim();
                                    if (code.isEmpty) return;
                                    _comingSoon('Promo redemption');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentBlue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Apply'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // f. Recent transactions section (real data)
                      const SizedBox(height: 16),
                      const Text(
                        'RECENT TRANSACTIONS',
                        style: AppTheme.labelUppercase,
                      ),
                      const SizedBox(height: 8),
                      Consumer<PaymentProvider>(
                        builder: (context, provider, _) {
                          if (provider.isLoading &&
                              provider.transactions.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.accentBlue),
                              ),
                            );
                          }
                          if (provider.transactions.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Text(
                                  'No transactions yet',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF555555)),
                                ),
                              ),
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0;
                                    i < provider.transactions.length;
                                    i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      color: AppTheme.borderColor,
                                      height: 1,
                                      thickness: 1,
                                    ),
                                  _TransactionRow(
                                      tx: provider.transactions[i]),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction row helper ───────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final PaymentTransaction tx;

  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final sign = isCredit ? '+' : '−';
    final amount =
        '$sign\$${tx.amount.abs().toStringAsFixed(2)}';
    final color =
        isCredit ? Colors.green.shade400 : Colors.red.shade400;
    final date = tx.createdAt == null
        ? ''
        : ' · ${tx.createdAt!.month}/${tx.createdAt!.day}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${tx.label}$date',
              style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add card bottom sheet ────────────────────────────────────────────────────

class _AddCardSheet extends StatefulWidget {
  final VoidCallback onClose;

  const _AddCardSheet({required this.onClose});

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _cardNumberController = TextEditingController();
  final _cardholderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardholderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final error = await context.read<PaymentProvider>().addCard(
          cardNumber: _cardNumberController.text,
          cardholderName: _cardholderController.text,
          expiry: _expiryController.text,
          cvv: _cvvController.text,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (error == null) {
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card added!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add card',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Card number
          TextField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            enabled: !_isSaving,
            decoration: const InputDecoration(hintText: 'Card number'),
          ),
          const SizedBox(height: 12),

          // Cardholder name
          TextField(
            controller: _cardholderController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'Cardholder name'),
          ),
          const SizedBox(height: 12),

          // Expiry + CVV row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  keyboardType: TextInputType.datetime,
                  enabled: !_isSaving,
                  decoration:
                      const InputDecoration(hintText: 'Expiry (MM/YY)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(hintText: 'CVV'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade400, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),

          // Add card button
          ElevatedButton(
            onPressed: _isSaving ? null : _handleAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Add card'),
          ),
          const SizedBox(height: 8),

          // Cancel button
          TextButton(
            onPressed: _isSaving ? null : widget.onClose,
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }
}
