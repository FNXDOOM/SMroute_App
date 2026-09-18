import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_tile.dart';
import '../../widgets/ui_kit.dart';

/// Inbox — the website's `InboxView`: title + unread count, "Mark all read"
/// while anything is unread, flat notification rows, and an intentional empty
/// state. Filters work on real notifications only.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  static const _filters = [
    NotifFilter.all,
    NotifFilter.rides,
    NotifFilter.payments,
    NotifFilter.promos,
  ];
  static const _filterLabels = ['All', 'Rides', 'Payments', 'Offers'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().loadNotifications();
    });
  }

  Future<void> _refresh() => context
      .read<NotificationProvider>()
      .loadNotifications(connectRealtime: false);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.filteredNotifications;
    final loading = provider.isLoading && !provider.isLoaded;
    final unread = provider.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: PageHeader(
                title: 'Notifications',
                description: provider.isLoaded && unread > 0
                    ? '$unread unread'
                    : 'Ride updates, receipts and announcements',
                onBack: () => Navigator.maybePop(context),
                backLabel: 'Home',
                actions: unread > 0
                    ? TextButton.icon(
                        onPressed: provider.markAllRead,
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Mark all read'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: SegmentedTabs(
                tabs: _filterLabels,
                activeIndex: _filters.indexOf(provider.activeFilter),
                onChanged: (i) =>
                    context.read<NotificationProvider>().setFilter(_filters[i]),
              ),
            ),
            Expanded(
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.gutter,
                      ),
                      child: SkeletonRows(count: 5, height: 76),
                    )
                  : RefreshIndicator(
                      color: AppColors.paper,
                      backgroundColor: AppColors.surface,
                      onRefresh: _refresh,
                      child: notifications.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.gutter,
                                vertical: AppSpacing.sm,
                              ),
                              children: [
                                EmptyState(
                                  icon: Icons.inbox_outlined,
                                  title: provider.error != null
                                      ? 'Unable to load notifications'
                                      : "You're all caught up",
                                  hint:
                                      provider.error ??
                                      'Ride updates, dispatch events and '
                                          'driver approvals will appear here.',
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.gutter,
                                0,
                                AppSpacing.gutter,
                                AppSpacing.xl,
                              ),
                              itemCount: notifications.length,
                              itemBuilder: (_, i) {
                                final notification = notifications[i];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: NotificationTile(
                                    notification: notification,
                                    onTap: notification.read
                                        ? null
                                        : () => context
                                              .read<NotificationProvider>()
                                              .markRead(notification.id),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
