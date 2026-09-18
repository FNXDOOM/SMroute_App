import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Driver application — the website's DriverApplyView on mobile: a licensed
/// driver applies with their vehicle's plate (`POST /auth/driver/apply`).
/// Same validation as the site: plate required.
class DriverApplyScreen extends StatefulWidget {
  const DriverApplyScreen({super.key});

  @override
  State<DriverApplyScreen> createState() => _DriverApplyScreenState();
}

class _DriverApplyScreenState extends State<DriverApplyScreen> {
  final TextEditingController _plateController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _applied = false;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) {
      setState(() => _error = 'Vehicle license plate is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.postJson(
        '/auth/driver/apply',
        body: <String, dynamic>{
          'license_plate': plate,
          'vehicle_model': 'Transit Shuttle',
          'capacity': 4,
        },
      );
      if (!mounted) return;
      setState(() => _applied = true);
      // Profile changed server-side — reload it so the role badge updates.
      await context.read<AuthProvider>().restoreSession();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not submit the application.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: _applied ? _buildDone() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 30, color: AppColors.paper),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SheetHeader(
          eyebrow: 'Application received',
          title: "You're in the queue",
          subtitle:
              'An operator verifies driver applications. Once approved, the '
              'driver console unlocks in this app.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Back to profile',
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Drive with SmartRoute',
          description:
              'Apply with your vehicle. Verification is done by operators in '
              'the admin console.',
          onBack: () => Navigator.maybePop(context),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('Vehicle license plate'),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _plateController,
          textCapitalization: TextCapitalization.characters,
          enabled: !_submitting,
          style: AppType.small.copyWith(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'KA-01-AB-1234',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Submit application',
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }
}
