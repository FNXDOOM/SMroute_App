import 'package:flutter/material.dart';

import '../models/carpool_stage.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// The passenger's carpool progress.
///
/// Shows the current stage, a progress bar, and every stage as a scrollable
/// chip so the rider can see where they are and what comes next. The stage list
/// mirrors the backend's per-rider lifecycle (see [CarpoolStage]).
class CarpoolStageStepper extends StatelessWidget {
  const CarpoolStageStepper({super.key, required this.stage});

  final CarpoolStage stage;

  @override
  Widget build(BuildContext context) {
    if (stage == CarpoolStage.cancelled) {
      return const ErrorBanner(message: 'This carpool ride was cancelled.');
    }

    // Cancelled is a terminal outcome rather than a step on the happy path.
    final stages =
        CarpoolStage.values.where((s) => s != CarpoolStage.cancelled).toList();
    final index = stages.indexOf(stage);
    final currentIndex = index == -1 ? stages.length - 1 : index;
    final progress =
        ((currentIndex + 1) / stages.length).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(stage.label, style: AppType.smallStrong)),
            Text(
              '${currentIndex + 1} / ${stages.length}',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.all(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.paper),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                AppChip(label: stages[i].label, selected: i == currentIndex),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
