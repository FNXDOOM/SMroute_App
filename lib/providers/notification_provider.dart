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
  String? _connectedToken;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _disposed = false;

  static const int _maxReconnectAttempts = 3;

  NotifFilter get activeFilter => _filter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.read).length;

  bool get isLoaded => _isLoaded;
  bool _isLoaded = false;

  List<AppNotification> get filteredNotifications {
    switch (_filter) {
      case NotifFilter.rides:
        return List.unmodifiable(
          _notifications.where((n) => n.type == NotificationType.ride),
        );
      case NotifFilter.promos:
        return List.unmodifiable(
          _notifications.where((n) => n.type == NotificationType.promo),
        );
      case NotifFilter.payments:
        return List.unmodifiable(
          _notifications.where((n) => n.type == NotificationType.payment),
        );
      case NotifFilter.all:
        return List.unmodifiable(_notifications);
    }
  }

  Future<void> loadNotifications({bool connectRealtime = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getJson('/notifications/?limit=100');
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Invalid notifications response');
      }
      final raw = response['notifications'] as List<dynamic>? ?? const [];
      final items = <AppNotification>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          items.add(AppNotification.fromJson(entry));
        } on FormatException {
          continue;
        }
      }
      _notifications
        ..clear()
        ..addAll(items);

      if (connectRealtime) {
        await _connectRealtime();
      }
    } on FormatException {
      _error = 'Unexpected server response.';
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
    _disconnectRealtime();
    _notifications.clear();
    _filter = NotifFilter.all;
    _error = null;
    _isLoaded = false;
    notifyListeners();
  }

  /// Reconnects when the auth token changes (login/logout/refresh).
  Future<void> reconnectIfTokenChanged() async {
    final token = await _api.token;
    if (token != _connectedToken) {
      _disconnectRealtime();
      if (token != null && token.isNotEmpty) {
        await _connectRealtime();
      }
    }
  }

  Future<void> _connectRealtime() async {
    if (_channel != null || _disposed) return;

    // Backend requires the JWT as a `token` query param and will close the
    // socket immediately if it's missing — grab it before connecting.
    final token = await _api.token;
    if (token == null || token.isEmpty) return;

    final wsUrl = _api.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    // Correct backend path is /notifications/ws (mounted under the
    // /notifications router prefix) — not /notifications/ws/notifications.
    final uri = Uri.parse('$wsUrl/notifications/ws').replace(
      queryParameters: {'token': token},
    );
    _connectedToken = token;
    _channel = WebSocketChannel.connect(uri);
    _socketSubscription = _channel!.stream.listen(
      (message) {
        _reconnectAttempts = 0;
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          if (data['type'] == 'notification' && data['notification'] is Map<String, dynamic>) {
            final raw = data['notification'] as Map<String, dynamic>;
            try {
              _upsertNotification(AppNotification.fromJson(raw));
            } on FormatException {
              return;
            }

            if (raw['notification_type'] == 'ride_status_updated') {
              // Backend serializes this field as `notification_metadata`,
              // not `metadata`.
              final metadata = raw['notification_metadata'] as Map<String, dynamic>?;
              if (metadata != null && metadata['new_status'] != null) {
                onRideStatusUpdated?.call(metadata['new_status'].toString());
              }
            }
          }
        } catch (_) {
          // Ignore malformed socket payloads.
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    _disconnectChannelOnly();
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    // Linear backoff: 2s, 4s, 6s.
    _reconnectTimer = Timer(Duration(seconds: 2 * _reconnectAttempts), () {
      if (!_disposed) unawaited(_connectRealtime());
    });
  }

  void _disconnectChannelOnly() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {
      // Already closed.
    }
    _channel = null;
  }

  void _disconnectRealtime() {
    _disconnectChannelOnly();
    _connectedToken = null;
    _reconnectAttempts = 0;
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
    _disposed = true;
    _disconnectRealtime();
    super.dispose();
  }
}
