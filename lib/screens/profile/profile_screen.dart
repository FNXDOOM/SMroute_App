import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/ride_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Profile — the website's `ProfileView`: avatar, name, email, role badge, then
/// editable name + phone with a single Save action (email is owned by the
/// identity provider and is display-only, exactly like the site).
///
/// The app-only additions are real, backend-backed screens: payment history
/// (`GET /payments/mine`) and sign-out. Nothing here is a placeholder — the
/// website has no settings, privacy or "coming soon" surfaces to mirror.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  String? _error;
  bool _seeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    final error = await auth.updateProfile(
      name: _nameController.text,
      phone: _phoneController.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
      _saved = error == null;
    });
    if (error == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: false,
      builder: (sheetContext) => SheetPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              eyebrow: 'Account',
              title: 'Sign out?',
              subtitle: "You'll need to sign in again to book rides.",
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign out',
              destructive: true,
              onPressed: () => Navigator.pop(sheetContext, true),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Stay signed in',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(sheetContext, false),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Clear per-account state so the next login never sees the previous
    // user's rides, notifications or payments.
    context.read<RideProvider>().clearForLogout();
    context.read<NotificationProvider>().clear();
    context.read<PaymentProvider>().clear();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    if (user == null) {
      // Session vanished (expired / signed out elsewhere) — back to bootstrap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/');
      });
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: SizedBox.shrink(),
      );
    }

    if (!_seeded) {
      _seeded = true;
      _nameController.text = user.name;
      _phoneController.text = user.phone;
    }

    // The backend refuses every driver endpoint unless driver_status is
    // 'active', so offering the console to an unapproved or suspended driver
    // would just hand them a screen full of permission errors.
    final isDriver = user.role == 'driver';
    final driverRoute = !isDriver
        ? '/driver-apply'
        : user.canDrive
            ? '/driver'
            : null;
    final driverSubtitle = !isDriver
        ? 'Apply to drive and earn on Smroute'
        : user.canDrive
            ? 'Duty, dispatch board and ride updates'
            : user.driverStatus == 'suspended'
                ? 'Suspended — the console is closed to you'
                : 'Awaiting verification — opens once approved';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Profile',
                description: 'How you appear to drivers and dispatch',
                onBack: () => Navigator.maybePop(context),
                backLabel: 'Home',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: AppRadius.all(AppRadius.lg),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            user.avatarLetter,
                            style: AppType.sectionTitle.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: AppType.cardTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: AppType.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: StatusBadge(status: user.role),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppField(
                      label: 'Full name',
                      controller: _nameController,
                      hint: 'Your name',
                      enabled: !_saving,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppField(
                      label: 'Phone',
                      controller: _phoneController,
                      hint: '+91 98765 43210',
                      keyboardType: TextInputType.phone,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ReadOnlyField(
                      label: 'Email',
                      value: user.email,
                      helper: 'Email is managed by your sign-in provider.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _saved ? 'Saved' : 'Save changes',
                      icon: _saved ? Icons.check : null,
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: ListRow(
                    title: user.canDrive
                        ? 'Driver console'
                        : 'Drive with Smroute',
                    subtitle: driverSubtitle,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadius.all(AppRadius.md),
                      ),
                      child: Icon(
                        isDriver
                            ? Icons.local_shipping_outlined
                            : Icons.directions_car_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: driverRoute == null
                        ? const SizedBox.shrink()
                        : const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.textSubtle,
                          ),
                    onTap: () {
                      if (driverRoute != null) {
                        Navigator.pushNamed(context, driverRoute);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: ListRow(
                    title: 'Payment history',
                    subtitle: 'Fares paid and refunds from your rides',
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadius.all(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textSubtle,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/payment'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Sign out',
                variant: AppButtonVariant.secondary,
                destructive: true,
                icon: Icons.logout,
                onPressed: _confirmSignOut,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display-only field (site: `disabled` input at 60% opacity).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value, this.helper});

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md + 1,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.field,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            value,
            style: AppType.small.copyWith(
              color: AppColors.textDisabled,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(
            helper!,
            style: AppType.caption.copyWith(color: AppColors.textSubtle),
          ),
        ],
      ],
    );
  }
}
