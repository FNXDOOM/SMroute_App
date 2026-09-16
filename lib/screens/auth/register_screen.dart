import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Create account — native counterpart of the website's Clerk sign-up card.
/// Same structure as [LoginScreen] (brand, eyebrow, title, fields, one primary
/// action) so the two auth screens read as one flow.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final auth = context.read<AuthProvider>();
    await auth.register(
      _nameController.text,
      _emailController.text,
      _phoneController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (auth.isAuthenticated) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xxl,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Brand ────────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: AppRadius.all(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.route,
                      size: 18,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'SmartRoute',
                    style: AppType.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // ── Headline ─────────────────────────────────────────────────
              const SectionLabel('Get started'),
              const SizedBox(height: AppSpacing.xs),
              const Text('Create your account', style: AppType.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign up to book rides, track drivers live and manage trips.',
                style: AppType.small.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              AppField(
                label: 'Full name',
                controller: _nameController,
                hint: 'Your full name',
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                enabled: !auth.isLoading,
              ),
              const SizedBox(height: AppSpacing.md),
              AppField(
                label: 'Email',
                controller: _emailController,
                hint: 'you@example.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !auth.isLoading,
              ),
              const SizedBox(height: AppSpacing.md),
              AppField(
                label: 'Phone number',
                controller: _phoneController,
                hint: '+91 98765 43210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                enabled: !auth.isLoading,
              ),
              const SizedBox(height: AppSpacing.md),
              AppField(
                label: 'Password',
                controller: _passwordController,
                hint: 'At least 6 characters',
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                enabled: !auth.isLoading,
                onSubmitted: (_) => _handleRegister(),
              ),

              if (auth.error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ErrorBanner(message: auth.error!),
              ],

              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Create account',
                loading: auth.isLoading,
                onPressed: auth.isLoading ? null : _handleRegister,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppType.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  PressableScale(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Sign in',
                      style: AppType.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(
                  color: AppColors.textSubtle,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
