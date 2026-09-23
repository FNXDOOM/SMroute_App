import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// One ordered stop of a carpool route, ready to render.
class CarpoolStopRow {
  const CarpoolStopRow({
    required this.sequence,
    required this.waypointType,
    required this.riders,
    this.walkMeters,
    this.isNext = false,
  });

  final int sequence;

  /// `depot` | `pickup` | `destination`.
  final String waypointType;

  /// Ride ids served at this stop (empty on the passenger's own view).
  final List<int> riders;

  /// Walking distance each rider at this pickup walks, when known.
  final double? walkMeters;

  /// The stop the driver should head to next (drawn in the accent).
  final bool isNext;

  bool get isPickup => waypointType == 'pickup';
  bool get isDepot => waypointType == 'depot';

  String get kindLabel => switch (waypointType) {
        'pickup' => 'Pickup',
        'destination' => 'Drop-off',
        'depot' => 'Depot',
        _ => 'Stop',
      };
}

/// The ordered pickup and drop-off stops of a carpool run.
///
/// The driver sees every rider and the next stop in the accent; the passenger
/// passes `riderLabel: null` so other riders stay private and only their own
/// stop (with its walking distance) is called out.
class CarpoolStopList extends StatelessWidget {
  const CarpoolStopList({
    super.key,
    required this.rows,
    this.riderLabel,
    this.riderStatus,
    this.emptyHint,
  });

  final List<CarpoolStopRow> rows;

  /// Masks a ride id for display; null hides rider labels entirely.
  final String Function(int rideId)? riderLabel;

  /// The rider's stage label, shown next to their id on the driver's view.
  final String Function(int rideId)? riderStatus;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.alt_route,
        title: 'Stops are being planned',
        hint: emptyHint ?? 'The ordered stops appear once the run is optimized.',
        compact: true,
      );
    }
    return Column(
      children: [
        for (final row in rows)
          _StopRow(
            row: row,
            riderLabel: riderLabel,
            riderStatus: riderStatus,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.row, this.riderLabel, this.riderStatus});

  final CarpoolStopRow row;
  final String Function(int rideId)? riderLabel;
  final String Function(int rideId)? riderStatus;

  @override
  Widget build(BuildContext context) {
    final accent = row.isNext;

    final details = <String>[];
    if (riderLabel != null && row.riders.isNotEmpty) {
      details.add(
        row.riders.map((id) {
          final status = riderStatus?.call(id);
          return status == null ? riderLabel!(id) : '${riderLabel!(id)} · $status';
        }).join(', '),
      );
    }
    if (row.isPickup && row.walkMeters != null) {
      details.add('Walk ${_metres(row.walkMeters!)}');
    }
    if (row.isNext) details.add('Next stop');

    return ListRow(
      leading: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: accent ? AppColors.accent : AppColors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(
            color: accent ? AppColors.accent : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${row.sequence + 1}',
          style: AppType.badge.copyWith(
            color: accent ? AppColors.paper : AppColors.gray200,
          ),
        ),
      ),
      title: row.kindLabel,
      subtitle: details.isEmpty ? null : details.join(' · '),
      emphasised: accent,
    );
  }

  static String _metres(double metres) {
    if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km';
    return '${(metres / 10).round() * 10} m';
  }
}
