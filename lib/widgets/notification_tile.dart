import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../theme/app_theme.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const NotificationTile({super.key, required this.notification});

  Color get _iconBgColor {
    switch (notification.type) {
      case NotificationType.ride:
        return AppTheme.accentBlue.withValues(alpha: 0.2);
      case NotificationType.promo:
        return const Color(0xFF7B3FF2).withValues(alpha: 0.2);
      case NotificationType.payment:
        return Colors.green.withValues(alpha: 0.2);
      case NotificationType.system:
        return const Color(0xFF333333);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.read ? AppTheme.readNotifBg : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: notification.read
              ? Colors.transparent
              : AppTheme.accentBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _iconBgColor,
            ),
            alignment: Alignment.center,
            child: Text(
              notification.icon,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: notification.read
                              ? const Color(0xFFCCCCCC)
                              : Colors.white,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    if (!notification.read) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Body
                Text(
                  notification.body,
                  style: AppTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Time
                Text(
                  notification.time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
