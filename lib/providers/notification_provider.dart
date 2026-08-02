import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/notification_model.dart';
import '../services/api_client.dart';

enum NotifFilter { all, rides, promos, payments }

class NotificationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  void Function(String)? onRideStatusUpdated;

  final List<AppNotification> _notifications = [];
  NotifFilter _filter = NotifFilter.all;
  bool _isLoading = false;
  String? _error;
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;

  NotifFilter get activeFilter => _filter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.read).length;

  bool get isLoaded => _isLoaded;
  bool _isLoaded = false;

  List<AppNotification> get filteredNotifications {
    switch (_filter) {
      case NotifFilter.rides:
        return _notifications.where((n) => n.type == NotificationType.ride).toList(growable: false);
      case NotifFilter.promos:
        return _notifications.where((n) => n.type == NotificationType.promo).toList(growable: false);
      case NotifFilter.payments:
        return _notifications.where((n) => n.type == NotificationType.payment).toList(growable: false);
      case NotifFilter.all:
        return List.unmodifiable(_notifications);
    }
  }

  Future<void> loadNotifications({bool connectRealtime = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getJson('/notifications?limit=100');
      final payload = response as Map<String, dynamic>;
      final items = (payload['notifications'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(growable: false);
      _notifications
        ..clear()
        ..addAll(items);

      if (connectRealtime) {
        _connectRealtime();
      }
    } catch (error) {
      _error = error is ApiException ? error.message : 'Unable to load notifications.';
    } finally {
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.patchJson('/notifications/read-all');
      for (final n in _notifications) {
        n.read = true;
      }
      notifyListeners();
    } catch (error) {
      _error = error is ApiException ? error.message : 'Unable to mark notifications read.';
      notifyListeners();
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _api.patchJson('/notifications/$notificationId/read');
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index].read = true;
        notifyListeners();
      }
    } catch (error) {
      _error = error is ApiException ? error.message : 'Unable to update notification.';
      notifyListeners();
    }
  }

  void setFilter(NotifFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    _filter = NotifFilter.all;
    _error = null;
    notifyListeners();
  }

  void _connectRealtime() {
    if (_channel != null) return;
    final wsUrl = _api.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsUrl/notifications/ws/notifications');
    _channel = WebSocketChannel.connect(uri);
    _socketSubscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          if (data['type'] == 'notification' && data['notification'] is Map<String, dynamic>) {
            final raw = data['notification'] as Map<String, dynamic>;
            _upsertNotification(AppNotification.fromJson(raw));

            if (raw['notification_type'] == 'ride_status_updated') {
              final metadata = raw['metadata'] as Map<String, dynamic>?;
              if (metadata != null && metadata['new_status'] != null) {
                onRideStatusUpdated?.call(metadata['new_status'].toString());
              }
            }
          }
        } catch (_) {
          // Ignore malformed socket payloads.
        }
      },
      onError: (_) {},
      onDone: () {
        _channel = null;
        _socketSubscription?.cancel();
        _socketSubscription = null;
      },
      cancelOnError: false,
    );
  }

  void _upsertNotification(AppNotification notification) {
    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index == -1) {
      _notifications.insert(0, notification);
    } else {
      _notifications[index] = notification;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
