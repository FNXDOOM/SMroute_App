import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/mock_data.dart';

enum NotifFilter { all, rides, promos, payments }

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = MockData.notifications;
  NotifFilter _filter = NotifFilter.all;

  // Cached filtered list — rebuilt only when filter or read-state changes.
  List<AppNotification>? _cachedFiltered;

  NotifFilter get activeFilter => _filter;

  int get unreadCount => _notifications.where((n) => !n.read).length;

  List<AppNotification> get filteredNotifications {
    _cachedFiltered ??= _buildFiltered();
    return _cachedFiltered!;
  }

  List<AppNotification> _buildFiltered() {
    switch (_filter) {
      case NotifFilter.rides:
        return _notifications
            .where((n) => n.type == NotificationType.ride)
            .toList(growable: false);
      case NotifFilter.promos:
        return _notifications
            .where((n) => n.type == NotificationType.promo)
            .toList(growable: false);
      case NotifFilter.payments:
        return _notifications
            .where((n) => n.type == NotificationType.payment)
            .toList(growable: false);
      case NotifFilter.all:
        return List.unmodifiable(_notifications);
    }
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    _cachedFiltered = null; // invalidate cache
    notifyListeners();
  }

  void setFilter(NotifFilter filter) {
    if (_filter == filter) return; // no-op if same filter
    _filter = filter;
    _cachedFiltered = null; // invalidate cache
    notifyListeners();
  }
}
