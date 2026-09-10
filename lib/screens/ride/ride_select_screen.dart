import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mock_data.dart';
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
  @override
  void initState() {
    super.initState();
    // Seed a default option only when none was chosen yet (e.g. deep link).
    // Otherwise keep the provider's existing selection as source of truth.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RideProvider>();
      // Sync destination passed via route arguments into the provider.
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.trim().isNotEmpty) {
        provider.setDestination(args.trim());
      }
      if (provider.selectedOption == null) {
        provider.selectOption(MockData.rideOptions.first);
      }
    });
  }

  void _confirmRide() async {
    final provider = context.read<RideProvider>();
    final ok = await provider.confirmBooking();
    if (!mounted) return;
    if (ok) {
      // Pass the provider's authoritative selection, not a stale local copy.
      Navigator.pushNamed(
        context,
        '/ride-confirm',
        arguments: provider.selectedOption,
      );
    } else {
      final msg = provider.error ?? 'Booking failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const MapWidget(showRoute: true, height: 192),
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
                      child: Consumer<RideProvider>(
                        builder: (context, provider, _) {
                          final dest = provider.destination?.trim() ?? '';
                          return Row(
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
                                  dest.isEmpty
                                      ? 'Choose a destination'
                                      : '→ $dest',
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
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. "Choose a ride" heading
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text('Choose a ride', style: AppTheme.headingSmall),
            ),

            // 3. Ride option list (single source of truth: provider)
            Expanded(
              child: Consumer<RideProvider>(
                builder: (context, provider, _) {
                  final selectedId = provider.selectedOption?.id;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: MockData.rideOptions.length,
                    itemBuilder: (context, index) {
                      final ride = MockData.rideOptions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RideOptionCard(
                          ride: ride,
                          isSelected: selectedId == ride.id,
                          onTap: () => provider.selectOption(ride),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 4. Book button
            Consumer<RideProvider>(
              builder: (context, provider, _) {
                final selected = provider.selectedOption;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: provider.isBooking ? null : _confirmRide,
                    child: provider.isBooking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(selected == null
                            ? 'Choose a ride'
                            : 'Book ${selected.name} · ${selected.priceRange}'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
