import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final String activeTab; // 'home' | 'trips' | 'inbox' | 'account'
  final VoidCallback onHome;
  final VoidCallback onTrips;
  final VoidCallback onInbox;
  final VoidCallback onAccount;
  final int notifCount;

  const BottomNavBar({
    super.key,
    required this.activeTab,
    required this.onHome,
    required this.onTrips,
    required this.onInbox,
    required this.onAccount,
    this.notifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(
          top: BorderSide(
            color: Color(0xFF1E1E1E),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: _TabButton(
                icon: '🏠',
                label: 'Home',
                isActive: activeTab == 'home',
                onTap: onHome,
              )),
              Expanded(child: _TabButton(
                icon: '🗺️',
                label: 'Trips',
                isActive: activeTab == 'trips',
                onTap: onTrips,
              )),
              Expanded(child: _InboxTabButton(
                isActive: activeTab == 'inbox',
                onTap: onInbox,
                notifCount: notifCount,
              )),
              Expanded(child: _TabButton(
                icon: '👤',
                label: 'Account',
                isActive: activeTab == 'account',
                onTap: onAccount,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : const Color(0xFF555555);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _InboxTabButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final int notifCount;

  const _InboxTabButton({
    required this.isActive,
    required this.onTap,
    required this.notifCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : const Color(0xFF555555);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Text(
                '🔔',
                style: TextStyle(fontSize: 20),
              ),
              if (notifCount > 0)
                Positioned(
                  top: -4,
                  right: -6,
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
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Inbox',
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
