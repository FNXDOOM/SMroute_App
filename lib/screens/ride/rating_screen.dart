import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    setState(() => _submitted = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Driver info header
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
                      child: const Center(
                        child: Text(
                          'M',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'How was your ride?',
                      style: AppTheme.headingMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Rate your experience with Marcus T.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
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
                    onTap: () => setState(() => _stars = i),
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
                      onTap: () => setState(() {
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
                  decoration: const InputDecoration(
                    hintText: 'Add a comment (optional)',
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Submit button
              AnimatedOpacity(
                opacity: _stars == 0 ? 0.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _stars == 0 ? null : _handleSubmit,
                  child: const Text('Submit rating'),
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
