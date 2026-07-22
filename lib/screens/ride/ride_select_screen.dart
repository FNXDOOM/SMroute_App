import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mock_data.dart';
import '../../models/ride_option.dart';
import '../../providers/ride_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/map_illustration.dart';
import '../../widgets/ride_option_card.dart';

class RideSelectScreen extends StatefulWidget {
  const RideSelectScreen({super.key});

  @override
  State<RideSelectScreen> createState() => _RideSelectScreenState();
}

class _RideSelectScreenState extends State<RideSelectScreen> {
  late RideOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = MockData.rideOptions.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().selectOption(MockData.rideOptions.first);
    });
  }

  void _confirmRide() {
    context.read<RideProvider>().confirmBooking();
    Navigator.pushNamed(context, '/ride-confirm', arguments: _selected);
  }

  @override
  Widget build(BuildContext context) {
    final destination =
        ModalRoute.of(context)!.settings.arguments as String? ?? '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Map with overlay
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Stack(
                children: [
                  MapWidget(showRoute: true, height: 192),
                  // Back button
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  // Route info bar
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xCC1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '→ $destination',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            '2.4 mi · 9 min',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. "Choose a ride" heading
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text('Choose a ride', style: AppTheme.headingSmall),
            ),

            // 3. Ride option list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: MockData.rideOptions.length,
                itemBuilder: (context, index) {
                  final ride = MockData.rideOptions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RideOptionCard(
                      ride: ride,
                      isSelected: _selected.id == ride.id,
                      onTap: () => setState(() {
                        _selected = ride;
                        context.read<RideProvider>().selectOption(ride);
                      }),
                    ),
                  );
                },
              ),
            ),

            // 4. Book button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _confirmRide,
                child: Text(
                    'Book ${_selected.name} · ${_selected.priceRange}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
