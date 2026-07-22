import 'package:flutter/material.dart';
import '../../models/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/trip_card.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _isPast = true;

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
                    // Past tab
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

                    // Scheduled tab
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: MockData.trips.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TripCard(trip: MockData.trips[i]),
      ),
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
            onPressed: () {},
            child: const Text('Schedule a ride'),
          ),
        ],
      ),
    );
  }
}
