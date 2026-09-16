enum NotificationType { ride, promo, payment, system }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String time;
  bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    if (rawId.isEmpty || rawId == 'null') {
      throw const FormatException('Notification missing valid id');
    }
    final type = _typeFromBackend((json['notification_type'] ?? '').toString());
    final createdAt = json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'].toString());
    return AppNotification(
      id: rawId,
      type: type,
      title: (json['title'] ?? 'Notification').toString(),
      body: (json['message'] ?? '').toString(),
      time: _timeLabel(createdAt),
      read: json['is_read'] == true,
    );
  }

  static NotificationType _typeFromBackend(String backendType) {
    if (backendType.startsWith('ride') || backendType.contains('tracking')) {
      return NotificationType.ride;
    }
    if (backendType.contains('payment')) {
      return NotificationType.payment;
    }
    if (backendType.contains('promo')) {
      return NotificationType.promo;
    }
    return NotificationType.system;
  }

  static String _timeLabel(DateTime? createdAt) {
    if (createdAt == null) return 'Just now';
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}
