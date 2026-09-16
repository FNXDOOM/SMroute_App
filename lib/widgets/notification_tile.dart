import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../theme/app_theme.dart';

/// Notification row in the website's language: hairline card, neutral
/// surface, line icon tile, muted body, white unread dot. No accent-tinted
/// borders, no emoji, no purple.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  final AppNotification notification;
  final VoidCallback? onTap;

  static IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.ride:
        return Icons.directions_car_outlined;
      case NotificationType.promo:
        return Icons.local_offer_outlined;
      case NotificationType.payment:
        return Icons.payments_outlined;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification.read;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: isRead ? AppColors.readSurface : AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: isRead ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadius.all(AppRadius.md),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  size: 18,
                  color: isRead ? AppColors.textSubtle : AppColors.paper,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppType.smallStrong.copyWith(
                              color: isRead
                                  ? AppColors.textSecondary
                                  : AppColors.paper,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.paper,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      notification.body,
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs + 2),
                    Text(
                      notification.time,
                      style: AppType.caption.copyWith(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
