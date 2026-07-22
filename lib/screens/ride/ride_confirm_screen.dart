import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_option.dart';
import '../../providers/ride_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/safety_features_grid.dart';

class RideConfirmScreen extends StatelessWidget {
  const RideConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ride = ModalRoute.of(context)!.settings.arguments as RideOption?;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Consumer<RideProvider>(
          builder: (context, provider, _) {
            switch (provider.stage) {
              case BookingStage.matching:
                return _MatchingView();
              case BookingStage.found:
                return _DriverFoundView(ride: ride, arriving: false);
              case BookingStage.arriving:
                return _DriverFoundView(ride: ride, arriving: true);
            }
          },
        ),
      ),
    );
  }
}

// ── Matching stage ─────────────────────────────────────────────────────────

class _MatchingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: AppTheme.accentBlue,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Finding your driver',
            style: AppTheme.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Matching you with the best nearby driver',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Found / Arriving stage ─────────────────────────────────────────────────

class _DriverFoundView extends StatelessWidget {
  final RideOption? ride;
  final bool arriving;

  const _DriverFoundView({required this.ride, required this.arriving});

  @override
  Widget build(BuildContext context) {
    final destination =
        context.read<RideProvider>().destination ?? '';

    final details = [
      _DetailRow(label: 'Vehicle', value: 'Toyota Camry'),
      _DetailRow(label: 'Plate', value: 'SF · 7K92M'),
      _DetailRow(label: 'Ride type', value: ride?.name ?? ''),
      _DetailRow(label: 'Destination', value: destination),
      _DetailRow(label: 'Estimated fare', value: ride?.priceRange ?? ''),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status pill
          Center(child: _StatusPill(ride: ride, arriving: arriving)),
          const SizedBox(height: 20),

          // Driver card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar + info + action buttons
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentBlue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'M',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + rating
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Marcus T.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Text('★',
                                  style: TextStyle(
                                      color: Colors.yellow, fontSize: 13)),
                              SizedBox(width: 4),
                              Text('4.98',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              SizedBox(width: 6),
                              Text('·',
                                  style: TextStyle(
                                      color: Color(0xFFAAAAAA), fontSize: 13)),
                              SizedBox(width: 6),
                              Text('1,204 trips',
                                  style: TextStyle(
                                      color: Color(0xFFAAAAAA), fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    Row(
                      children: [
                        _CircleIconButton(label: '💬'),
                        const SizedBox(width: 8),
                        _CircleIconButton(label: '📞'),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Detail rows
                ...details.map((d) => d),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Safety features
          const SafetyFeaturesGrid(),

          const SizedBox(height: 16),

          // Done button
          ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/rating',
              (r) => r.settings.name == '/home',
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ── Status pill ────────────────────────────────────────────────────────────

class _StatusPill extends StatefulWidget {
  final RideOption? ride;
  final bool arriving;

  const _StatusPill({required this.ride, required this.arriving});

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_pulse);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arriving = widget.arriving;

    final bgColor = arriving
        ? Colors.green.withValues(alpha: 0.15)
        : AppTheme.accentBlue.withValues(alpha: 0.15);
    final borderColor = arriving
        ? Colors.green.withValues(alpha: 0.3)
        : AppTheme.accentBlue.withValues(alpha: 0.3);
    final textColor =
        arriving ? Colors.green.shade400 : AppTheme.accentBlue;
    final label = arriving
        ? 'Driver arriving in ~1 min'
        : 'Driver on the way · ${widget.ride?.eta ?? ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing dot
          FadeTransition(
            opacity: _opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Detail row ─────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppTheme.borderColor),
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Circle icon button ─────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final String label;

  const _CircleIconButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFF252525),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
