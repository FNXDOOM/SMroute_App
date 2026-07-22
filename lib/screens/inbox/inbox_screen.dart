import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_tile.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)),
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/home'),
                  ),
                  // Title
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // Mark all read / spacer
                  Consumer<NotificationProvider>(
                    builder: (context, provider, _) {
                      if (provider.unreadCount > 0) {
                        return TextButton(
                          onPressed: () =>
                              context.read<NotificationProvider>().markAllRead(),
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        );
                      }
                      return const SizedBox(width: 80);
                    },
                  ),
                ],
              ),
            ),

            // ── Filter tabs ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ('all', 'All'),
                    ('rides', 'Rides'),
                    ('promos', 'Promos'),
                    ('payments', 'Payments'),
                  ].map((entry) {
                    final filterKey = entry.$1;
                    final label = entry.$2;
                    return Consumer<NotificationProvider>(
                      builder: (context, provider, _) {
                        final isActive =
                            provider.activeFilter.name == filterKey;
                        return GestureDetector(
                          onTap: () {
                            final filter = NotifFilter.values.firstWhere(
                              (f) => f.name == filterKey,
                            );
                            context
                                .read<NotificationProvider>()
                                .setFilter(filter);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.black
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Notification list ────────────────────────────────────────────
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, provider, _) {
                  final filtered = provider.filteredNotifications;
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🔔',
                            style: TextStyle(fontSize: 48),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No notifications here yet',
                            style: TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NotificationTile(notification: filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
