import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bottom navigation mirroring the website's passenger nav
/// (Ride: Home / My Trips — Account: Inbox / Profile), rebuilt with line icons
/// and the site's neutral palette (active = white, inactive = #8A8A8A).
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.activeTab,
    required this.onHome,
    required this.onTrips,
    required this.onInbox,
    required this.onAccount,
    this.notifCount = 0,
  });

  /// 'home' | 'trips' | 'inbox' | 'account'
  final String activeTab;
  final VoidCallback onHome;
  final VoidCallback onTrips;
  final VoidCallback onInbox;
  final VoidCallback onAccount;
  final int notifCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _Tab(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                isActive: activeTab == 'home',
                onTap: onHome,
              ),
              _Tab(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Trips',
                isActive: activeTab == 'trips',
                onTap: onTrips,
              ),
              _Tab(
                icon: Icons.inbox_outlined,
                activeIcon: Icons.inbox,
                label: 'Inbox',
                isActive: activeTab == 'inbox',
                onTap: onInbox,
                badgeCount: notifCount,
              ),
              _Tab(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: activeTab == 'account',
                onTap: onAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.paper : AppColors.textSubtle;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isActive ? activeIcon : icon, size: 21, color: color),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: AppRadius.all(AppRadius.pill),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: AppType.badge.copyWith(
                          color: AppColors.ink,
                          fontSize: 9,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
