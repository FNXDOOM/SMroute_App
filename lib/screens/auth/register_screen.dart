import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final auth = context.read<AuthProvider>();
    await auth.register(
      _nameController.text,
      _emailController.text,
      _phoneController.text,
      _passwordController.text,
    );
    if (mounted && auth.isAuthenticated) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create your\naccount',
                    style: AppTheme.headingLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign up to start riding',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // ── Form ─────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full Name
                        const Text('FULL NAME', style: AppTheme.labelUppercase),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Your full name',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Email
                        const Text('EMAIL', style: AppTheme.labelUppercase),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'your@email.com',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Phone Number
                        const Text(
                          'PHONE NUMBER',
                          style: AppTheme.labelUppercase,
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '+1 (555) 000-0000',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password
                        const Text('PASSWORD', style: AppTheme.labelUppercase),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '••••••••',
                          ),
                          onSubmitted: (_) => _handleRegister(),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (auth.error != null) ...[
                          Text(
                            auth.error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Create account button
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleRegister,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create account'),
                        ),
                        const SizedBox(height: 24),

                        // Sign in link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
