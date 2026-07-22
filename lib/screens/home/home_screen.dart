import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/ride_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/map_illustration.dart';
import '../../widgets/promo_banner.dart';

// Cached static decorations — allocated once, never rebuilt.
const _searchBoxDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusLg)),
  boxShadow: [
    BoxShadow(
      color: Color(0x26000000), // black @ ~15% opacity
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ],
);

const _cityLabelDecoration = BoxDecoration(
  color: Color(0xA6000000), // black @ ~65%
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _destController = TextEditingController();
  bool _showPushBanner = true;
  bool _pushGranted = false;

  @override
  void initState() {
    super.initState();
    // Listener only triggers a rebuild of the search sub-widget via ValueListenableBuilder.
  }

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final dest = _destController.text.trim();
    if (dest.isEmpty) return;
    context.read<RideProvider>().setDestination(dest);
    Navigator.pushNamed(context, '/ride-select', arguments: dest);
  }

  void _navigateToRide(String address) {
    _destController.text = address;
    context.read<RideProvider>().setDestination(address);
    Navigator.pushNamed(context, '/ride-select', arguments: address);
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    // Read auth once — only rebuilds if user itself changes (login/logout).
    final user = context.select<AuthProvider, String>(
      (a) => a.currentUser?.name ?? 'Rider',
    );
    final firstName = user.split(' ').first;

    // Read only unreadCount — rebuilds only when badge number changes.
    final notifCount = context.select<NotificationProvider, int>(
      (n) => n.unreadCount,
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Top bar ───────────────────────────────────────────────
            _TopBar(
              firstName: firstName,
              notifCount: notifCount,
            ),

            // ── 2. Promo banner ─────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: PromoBanner(),
            ),

            // ── 3. Push notification permission banner ───────────────────
            if (_showPushBanner && !_pushGranted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _PushBanner(
                  onAllow: () => setState(() => _pushGranted = true),
                  onDismiss: () => setState(() => _showPushBanner = false),
                ),
              ),

            // ── 4. Map ───────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _MapSection(),
            ),

            // ── 5 & 6. Search + Find button (ValueListenableBuilder so
            //    only this subtree rebuilds on every keystroke) ───────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _destController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search box
                      Container(
                        decoration: _searchBoxDecoration,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Text('🔍',
                                style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _destController,
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'Where to?',
                                  hintStyle: TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 14),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                ),
                                onSubmitted: (_) => _onSearch(),
                              ),
                            ),
                            if (hasText)
                              GestureDetector(
                                onTap: _destController.clear,
                                child: const Icon(Icons.close,
                                    size: 18,
                                    color: Color(0xFF999999)),
                              ),
                          ],
                        ),
                      ),
                      // Find a ride button
                      if (hasText) ...[
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _onSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Find a ride →'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // ── 7. Recent places ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECENT PLACES',
                          style: AppTheme.labelUppercase),
                      const SizedBox(height: 8),
                      _RecentPlaceTile(
                        emoji: '🏠',
                        title: 'Home',
                        subtitle: '142 Maple Drive',
                        onTap: () =>
                            _navigateToRide('142 Maple Drive'),
                      ),
                      _RecentPlaceTile(
                        emoji: '💼',
                        title: 'Work',
                        subtitle: '1 Market St Suite 300',
                        onTap: () =>
                            _navigateToRide('1 Market St Suite 300'),
                      ),
                      _RecentPlaceTile(
                        emoji: '🏋️',
                        title: 'Gym',
                        subtitle: 'FitLife 90 Howard St',
                        onTap: () =>
                            _navigateToRide('FitLife 90 Howard St'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 8. Bottom nav ────────────────────────────────────────────
            BottomNavBar(
              activeTab: 'home',
              onHome: () {},
              onTrips: () =>
                  Navigator.pushReplacementNamed(context, '/trips'),
              onInbox: () =>
                  Navigator.pushReplacementNamed(context, '/inbox'),
              onAccount: () =>
                  Navigator.pushReplacementNamed(context, '/profile'),
              notifCount: notifCount,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extracted sub-widgets (const-constructible) ──────────────────────────────

class _TopBar extends StatelessWidget {
  final String firstName;
  final int notifCount;
  const _TopBar({required this.firstName, required this.notifCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _HomeScreenState._greeting(),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF888888)),
                ),
                Text(
                  firstName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),
          // Bell button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/inbox'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      size: 18, color: Colors.white),
                ),
                if (notifCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentBlue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        notifCount > 9 ? '9+' : '$notifCount',
                        style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppTheme.accentBlue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                firstName[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const MapWidget(showRoute: false, height: 192),
        // Location dot
        const Positioned.fill(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(
                  width: 2,
                  height: 20,
                  child: ColoredBox(color: AppTheme.accentBlue),
                ),
              ],
            ),
          ),
        ),
        // City label
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            decoration: _cityLabelDecoration,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: const Text(
              '📍 San Francisco, CA',
              style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PushBanner extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onDismiss;
  const _PushBanner({required this.onAllow, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withValues(alpha: 0.1),
        border: Border.all(
            color: AppTheme.accentBlue.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppTheme.accentBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_outlined,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable ride notifications',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Stay updated on your driver's arrival",
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close,
                    size: 18, color: Color(0xFF888888)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAllow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Allow'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentPlaceTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RecentPlaceTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(emoji,
            style: const TextStyle(fontSize: 18)),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF666666))),
      trailing: const Text('›',
          style: TextStyle(fontSize: 20, color: Color(0xFF444444))),
      onTap: onTap,
    );
  }
}
