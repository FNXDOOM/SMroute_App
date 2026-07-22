import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SafetyFeaturesGrid extends StatelessWidget {
  const SafetyFeaturesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SAFETY FEATURES', style: AppTheme.labelUppercase),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SafetyButton(icon: '🛡️', label: 'Share trip')),
              const SizedBox(width: 8),
              Expanded(child: _SafetyButton(icon: '🚨', label: 'Emergency')),
              const SizedBox(width: 8),
              Expanded(child: _SafetyButton(icon: '📍', label: 'Track live')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafetyButton extends StatelessWidget {
  final String icon;
  final String label;

  const _SafetyButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
