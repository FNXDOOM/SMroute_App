import 'package:flutter/material.dart';

import '../models/ride_option.dart';
import '../theme/app_theme.dart';

/// Ride tier row — the website's `ride-tier` radio card: 12px radius, hairline
/// border, 44px icon tile, name + "desc · eta · seats", bold tabular price.
/// Selected state uses the site's black/white emphasis instead of an accent.
class RideOptionCard extends StatelessWidget {
  const RideOptionCard({
    super.key,
    required this.ride,
    required this.isSelected,
    required this.onTap,
  });

  final RideOption ride;
  final bool isSelected;
  final VoidCallback onTap;

  /// The backend's option IDs are the source of truth (see README.md);
  /// map each to the closest line icon from the website's set.
  static IconData _iconFor(String id) {
    switch (id) {
      case 'swift-xl':
        return Icons.group_outlined;
      case 'swift-lux':
        return Icons.workspace_premium_outlined;
      case 'swift-moto':
        return Icons.two_wheeler_outlined;
      case 'swift-x':
      default:
        return Icons.directions_car_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.all(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surfaceAlt : Colors.transparent,
              borderRadius: AppRadius.all(AppRadius.lg),
              border: Border.all(
                color: isSelected ? AppColors.paper : AppColors.border,
              ),
              boxShadow: isSelected ? AppShadows.sm : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  // Icon tile — inverted when selected (site recipe).
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.paper
                          : AppColors.surfaceAlt,
                      borderRadius: AppRadius.all(AppRadius.md),
                    ),
                    child: Icon(
                      _iconFor(ride.id),
                      size: 19,
                      color: isSelected
                          ? AppColors.ink
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.name,
                          style: AppType.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ride.description} · ${ride.eta} · '
                          '${ride.seats} seats',
                          style: AppType.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    ride.priceRange,
                    style: AppType.data,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
