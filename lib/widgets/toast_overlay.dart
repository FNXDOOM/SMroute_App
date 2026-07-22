import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ToastType { info, success, warning, promo }

class ToastModel {
  final String id;
  final ToastType type;
  final String title;
  final String body;
  final String icon;

  ToastModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.icon,
  });
}

class ToastOverlay extends StatefulWidget {
  final Widget child;
  const ToastOverlay({super.key, required this.child});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  final List<ToastModel> _toasts = [];
  final Map<String, Timer> _timers = {};

  void addToast(ToastModel toast) {
    setState(() => _toasts.add(toast));
    _timers[toast.id] = Timer(const Duration(seconds: 4), () => _dismiss(toast.id));
  }

  void _dismiss(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    if (mounted) setState(() => _toasts.removeWhere((t) => t.id == id));
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 48,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 340,
              child: Column(
                children: _toasts
                    .map((t) => _ToastItem(toast: t, onDismiss: _dismiss))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastItem extends StatelessWidget {
  final ToastModel toast;
  final void Function(String id) onDismiss;

  const _ToastItem({required this.toast, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(toast.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toast.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  toast.body,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onDismiss(toast.id),
            child: const Text(
              '✕',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
