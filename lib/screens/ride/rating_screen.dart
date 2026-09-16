import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ride_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Post-ride feedback.
///
/// NOTE: this screen is app-only — the website has no rating step, and the
/// backend currently exposes no feedback endpoint. The submit call is
/// best-effort and a 404 never blocks the flow (see README.md).
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  static const _tags = [
    'Great driving',
    'Very clean',
    'On time',
    'Friendly',
    'Quiet ride',
    'Safe driver',
  ];

  int _stars = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _submitted = false;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_stars == 0 || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    final rideId = context.read<RideProvider>().currentRideId;
    try {
      if (rideId != null) {
        try {
          await ApiClient.instance.postJson(
            '/rides/$rideId/rating',
            body: {
              'stars': _stars,
              'tags': _selectedTags.toList(),
              'comment': _commentController.text.trim(),
            },
          );
        } on ApiException catch (e) {
          // Best-effort only — an absent endpoint must not block the user.
          if (e.statusCode != 404) rethrow;
        }
      }
      if (!mounted) return;
      setState(() => _submitted = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      context.read<RideProvider>().reset();
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e is ApiException
            ? e.message
            : 'Could not submit feedback. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _submitted ? _buildSuccessState() : _buildRatingForm(),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.check, size: 30, color: AppColors.paper),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Thanks for the feedback',
              style: AppType.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Heading back to home…',
              style: AppType.small.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingForm() {
    final provider = context.watch<RideProvider>();
    final vehicle = provider.assignedVehicle;
    final ride = provider.activeRideRecord;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: AppRadius.all(AppRadius.lg),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.directions_car_outlined,
                size: 28,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SheetHeader(
              eyebrow: 'Ride complete',
              title: 'How was your ride?',
              subtitle: 'Your feedback helps improve shared transit.',
            ),
            if (ride != null) ...[
              const SizedBox(height: AppSpacing.md),
              RouteLeg(
                pickup: ride.pickupLabel,
                destination: ride.destinationLabel,
              ),
            ],
            if (vehicle != null) ...[
              const SizedBox(height: AppSpacing.md),
              InfoRow(label: 'Vehicle', value: vehicle.licensePlate),
            ],
            const SizedBox(height: AppSpacing.xl),
            StarRating(
              value: _stars,
              enabled: !_isSubmitting,
              onChanged: (value) => setState(() => _stars = value),
            ),
            if (_stars > 0) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('What stood out?'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tag in _tags)
                    AppChip(
                      label: tag,
                      selected: _selectedTags.contains(tag),
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() {
                              if (!_selectedTags.remove(tag)) {
                                _selectedTags.add(tag);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Anything else?'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _commentController,
                maxLines: 3,
                enabled: !_isSubmitting,
                style: AppType.small.copyWith(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                ),
              ),
            ],
            if (_submitError != null) ...[
              const SizedBox(height: AppSpacing.md),
              ErrorBanner(message: _submitError!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Submit',
              loading: _isSubmitting,
              onPressed: _stars == 0 ? null : _handleSubmit,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Skip',
              variant: AppButtonVariant.secondary,
              onPressed: _isSubmitting
                  ? null
                  : () {
                      context.read<RideProvider>().reset();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (_) => false,
                      );
                    },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
