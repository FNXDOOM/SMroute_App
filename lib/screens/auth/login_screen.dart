import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final auth = context.read<AuthProvider>();
    await auth.login(_emailController.text, _passwordController.text);
    if (mounted && auth.isAuthenticated) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  /// Step 2 of website-account sign-in: verify the emailed 6-digit code.
  void _handleVerifyCode() async {
    final auth = context.read<AuthProvider>();
    await auth.verifyEmailCode(_codeController.text);
    if (mounted && auth.isAuthenticated) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  void _handleResendCode() async {
    await context.read<AuthProvider>().resendEmailCode();
  }

  void _handleCancelCode() async {
    _codeController.clear();
    await context.read<AuthProvider>().cancelEmailCode();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isCodeStep = auth.isAwaitingEmailCode;

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
              SectionLabel(isCodeStep ? 'Verification' : 'Sign in'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isCodeStep ? 'Check your email' : 'Welcome back',
                style: AppType.pageTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isCodeStep
                    ? 'We sent a 6-digit code to ${auth.pendingEmail}. '
                        'Enter it below to continue.'
                    : 'Sign in with the email and password you registered '
                        'with.',
                style: AppType.small.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (isCodeStep) ...[
                // ── Email-code step (website accounts) ───────────────────
                AppField(
                  label: 'Verification code',
                  controller: _codeController,
                  hint: '000000',
                  icon: Icons.password_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  fontSize: 22,
                  letterSpacing: 6,
                  onSubmitted: (_) => _handleVerifyCode(),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ErrorBanner(message: auth.error!),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Verify code',
                  loading: auth.isLoading,
                  onPressed: auth.isLoading ? null : _handleVerifyCode,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Resend code',
                        variant: AppButtonVariant.ghost,
                        expand: false,
                        height: 44,
                        onPressed:
                            auth.isLoading ? null : _handleResendCode,
                      ),
                    ),
                    Expanded(
                      child: AppButton(
                        label: 'Use a different email',
                        variant: AppButtonVariant.ghost,
                        expand: false,
                        height: 44,
                        onPressed:
                            auth.isLoading ? null : _handleCancelCode,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // ── Email / password step ────────────────────────────────
                AppField(
                  label: 'Email',
                  controller: _emailController,
                  hint: 'you@example.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: 'Password',
                  controller: _passwordController,
                  hint: 'Your password',
                  icon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ErrorBanner(message: auth.error!),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Continue',
                  loading: auth.isLoading,
                  onPressed: auth.isLoading ? null : _handleLogin,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Hairline divider with centered label (site separator).
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        'or',
                        style: AppType.caption.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Create account',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                ),
              ],

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
