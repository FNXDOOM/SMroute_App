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
    final args = ModalRoute.of(context)?.settings.arguments;
    final rideArg = args is RideOption ? args : null;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Consumer<RideProvider>(
          builder: (context, provider, _) {
            // Prefer the provider's authoritative booking; fall back to the
            // route argument (e.g. after process restore).
            final ride = provider.selectedOption ?? rideArg;
            switch (provider.stage) {
              case BookingStage.matching:
                return const _MatchingView();
              case BookingStage.found:
                return _DriverFoundView(ride: ride, arriving: false);
              case BookingStage.arriving:
                return _DriverFoundView(ride: ride, arriving: true);
              case BookingStage.completed:
                return _TerminalView(
                  ride: ride,
                  title: 'Ride completed',
                  subtitle: 'Thanks for riding with SmartRoute.',
                  isSuccess: true,
                );
              case BookingStage.cancelled:
                return _TerminalView(
                  ride: ride,
                  title: 'Ride cancelled',
                  subtitle: 'This ride was cancelled. No charge was made.',
                  isSuccess: false,
                );
            }
          },
        ),
      ),
    );
  }
}

class _TerminalView extends StatelessWidget {
  final RideOption? ride;
  final String title;
  final String subtitle;
  final bool isSuccess;

  const _TerminalView({
    required this.ride,
    required this.title,
    required this.subtitle,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isSuccess ? Colors.green : Colors.red)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                isSuccess ? '✓' : '✕',
                style: TextStyle(
                  fontSize: 36,
                  color: isSuccess ? Colors.green : Colors.red.shade400,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: AppTheme.headingMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textTertiary),
                textAlign: TextAlign.center),
            if (ride != null) ...[
              const SizedBox(height: 12),
              Text('${ride!.name} · ${ride!.priceRange}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFAAAAAA))),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/rating',
                (_) => false,
              ),
              child: const Text('Continue to rating'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (_) => false,
              ),
              child: const Text('Back to home',
                  style: TextStyle(color: Color(0xFF888888))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Matching stage ─────────────────────────────────────────────────────────

class _MatchingView extends StatelessWidget {
  const _MatchingView();

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
    final rideProvider = context.watch<RideProvider>();
    final destination = rideProvider.destination ?? '';
    final vehicle = rideProvider.assignedVehicle;

    // Vehicle make/model has no backend equivalent (Vehicle only stores
    // license_plate, capacity, status, lat/lng) — plate + status are real,
    // the "Toyota Camry"-style description stays a placeholder until the
    // backend adds a vehicle model/make field.
    final vehicleLine = vehicle != null
        ? vehicle.licensePlate
        : (rideProvider.vehicleAssignmentTimedOut
            ? 'Not available for this ride'
            : 'Assigning a vehicle\u2026');
    final plateLine = vehicle != null ? vehicle.status : '\u2014';

    final details = [
      _DetailRow(label: 'Vehicle', value: vehicleLine),
      _DetailRow(label: 'Status', value: plateLine),
      _DetailRow(label: 'Ride type', value: ride?.name ?? ''),
      _DetailRow(label: 'Destination', value: destination),
      _DetailRow(label: 'Estimated fare', value: ride?.priceRange ?? ''),
      if (vehicle?.lat != null && vehicle?.lng != null)
        _DetailRow(
          label: 'Live position',
          value:
              '${vehicle!.lat!.toStringAsFixed(4)}, ${vehicle.lng!.toStringAsFixed(4)}',
        ),
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
                        '\ud83d\ude97',
                        style: TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + rating
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // No driver-identity field exists on the backend
                          // Vehicle/User models yet, so this stays generic
                          // rather than showing a fabricated name.
                          const Text(
                            'Your driver',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle != null
                                ? 'Vehicle #${vehicle.id}'
                                : 'Matching to a vehicle',
                            style: const TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action buttons (driver contact not yet supported
                    // by backend — show feedback instead of dead buttons).
                    Row(
                      children: [
                        _CircleIconButton(
                          label: '\ud83d\udcac',
                          tooltip: 'Chat with driver (coming soon)',
                        ),
                        const SizedBox(width: 8),
                        _CircleIconButton(
                          label: '\ud83d\udcde',
                          tooltip: 'Call driver (coming soon)',
                        ),
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

          // Done button — always keep a way back home even when /home
          // isn't already in the stack (deep links, restores).
          ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/rating',
              (_) => false,
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
  final String tooltip;

  const _CircleIconButton({required this.label, this.tooltip = 'Coming soon'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tooltip),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      ),
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
