import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_request_record.dart';
import '../../providers/ride_provider.dart';
import '../../theme/app_theme.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _isPast = true;

  @override
  void initState() {
    super.initState();
    // Load rides from backend when screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().loadMyRides();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20)
                  .copyWith(top: 16, bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF888888)),
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/home'),
                  ),
                  Expanded(
                    child: Text(
                      'Your trips',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Tab switcher ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16)
                  .copyWith(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMd),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isPast = true),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isPast
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Past',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isPast
                                  ? Colors.black
                                  : const Color(0xFF888888),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isPast = false),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isPast
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Scheduled',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !_isPast
                                  ? Colors.black
                                  : const Color(0xFF888888),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _isPast ? _buildPastList() : _buildScheduledEmpty(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastList() {
    return Consumer<RideProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingRides) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentBlue),
          );
        }

        final rides = provider.myRides;

        if (rides.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🚗', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text(
                  'No past trips yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Book your first ride and it will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.accentBlue,
          backgroundColor: AppTheme.surfaceColor,
          onRefresh: () => context.read<RideProvider>().loadMyRides(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: rides.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RideCard(ride: rides[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduledEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🗓️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'No scheduled rides',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book rides up to 7 days in advance',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/home'),
            child: const Text('Schedule a ride'),
          ),
        ],
      ),
    );
  }
}

/// Adapter card that renders a [RideRequestRecord] in the trips list.
class _RideCard extends StatelessWidget {
  final RideRequestRecord ride;
  const _RideCard({required this.ride});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade400;
      case 'cancelled':
        return Colors.red.shade400;
      case 'in_progress':
        return AppTheme.accentBlue;
      default:
        return const Color(0xFFAAAAAA);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays == 0) return 'Today, ${_hm(dt)}';
    if (diff.inDays == 1) return 'Yesterday, ${_hm(dt)}';
    return '${_monthName(dt.month)} ${dt.day}, ${_hm(dt)}';
  }

  String _hm(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  String _monthName(int m) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(ride.requestTime),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(ride.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ride.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(ride.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Route
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked,
                      color: AppTheme.accentBlue, size: 14),
                  Container(
                    width: 1,
                    height: 20,
                    color: const Color(0xFF444444),
                  ),
                  const Icon(Icons.location_on,
                      color: Colors.red, size: 14),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.pickupLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ride.destinationLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Ride option + ID footer
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ride.rideOptionName != null
                    ? '${ride.rideOptionName}${ride.rideOptionPrice != null ? ' · ${ride.rideOptionPrice}' : ''}'
                    : 'Ride #${ride.id}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
              ),
              if (ride.clusterId != null)
                Text(
                  'Cluster ${ride.clusterId}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
