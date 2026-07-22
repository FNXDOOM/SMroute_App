enum NotificationType { ride, promo, payment, system }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String time;
  bool read;
  final String icon;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.read,
    required this.icon,
  });
}
