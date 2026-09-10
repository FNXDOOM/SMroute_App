import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
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
        // Best-effort: backend may not have a rating endpoint yet.
        // A 404 must not block the success UX.
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
          if (e.statusCode != 404) rethrow;
        }
      }
      if (!mounted) return;
      setState(() => _submitted = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      context.read<RideProvider>().reset();
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e is ApiException
            ? e.message
            : 'Could not submit rating. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: _submitted ? _buildSuccessState() : _buildRatingForm(),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(fontSize: 36, color: Colors.green),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Thanks for rating!',
            style: AppTheme.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Your feedback helps improve the community',
              style: TextStyle(fontSize: 14, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingForm() {
    final vehicle = context.watch<RideProvider>().assignedVehicle;
    final subtitle = vehicle != null
        ? 'Rate your ride · Vehicle #${vehicle.id}'
        : 'Rate your ride with your driver';
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Driver info header (generic — backend has no driver identity).
              Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 24),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentBlue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '🚗',
                        style: TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'How was your ride?',
                      style: AppTheme.headingMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Stars row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3, 4, 5].map((i) {
                  return GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _stars = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        i <= _stars ? '★' : '☆',
                        style: TextStyle(
                          fontSize: 40,
                          color: i <= _stars
                              ? const Color(0xFFFACC15)
                              : const Color(0xFF333333),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Tags and comment (shown only when stars > 0)
              if (_stars > 0) ...[
                const SizedBox(height: 20),
                const Text('WHAT STOOD OUT?', style: AppTheme.labelUppercase),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Great driving',
                    'Very clean',
                    'On time',
                    'Friendly',
                    'Quiet ride',
                    'Safe driver',
                  ].map((t) {
                    final selected = _selectedTags.contains(t);
                    return GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() {
                                if (selected) {
                                  _selectedTags.remove(t);
                                } else {
                                  _selectedTags.add(t);
                                }
                              }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF2A2A2A),
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? Colors.black
                                : const Color(0xFF888888),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment (optional)',
                  ),
                ),
              ],

              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _submitError!,
                  style: TextStyle(
                      color: Colors.red.shade400, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              // Submit button
              AnimatedOpacity(
                opacity: _stars == 0 || _isSubmitting ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: (_stars == 0 || _isSubmitting)
                      ? null
                      : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Submit rating'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
