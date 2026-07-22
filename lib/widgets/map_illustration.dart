import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MapWidget extends StatelessWidget {
  final bool showRoute;
  final double height;
  const MapWidget(
      {super.key, this.showRoute = false, this.height = 192});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.all(Radius.circular(AppTheme.radiusMd)),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: showRoute
              ? const _MapPainter(showRoute: true)
              : const _MapPainter(showRoute: false),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool showRoute;
  const _MapPainter({required this.showRoute});

  // Static Paint objects — allocated once per isolate, never GC'd.
  static final Paint _bgPaint = Paint()
    ..color = const Color(0xFF1A1A1A);
  static final Paint _gridPaint = Paint()
    ..color = const Color(0xFF222222);
  static final Paint _roadPaint = Paint()
    ..color = const Color(0xFF252525);
  static final Paint _dashPaint = Paint()
    ..color = const Color(0xFF333333);
  static final Paint _buildingPaint = Paint()
    ..color = const Color(0xFF242424);
  static final Paint _routePaint = Paint()
    ..color = const Color(0xFF276EF1)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  // Pre-computed building rects — allocated once.
  static const List<Rect> _buildings = [
    Rect.fromLTWH(20, 50, 20, 14),
    Rect.fromLTWH(90, 120, 20, 14),
    Rect.fromLTWH(130, 45, 20, 14),
    Rect.fromLTWH(220, 115, 20, 14),
    Rect.fromLTWH(260, 50, 20, 14),
    Rect.fromLTWH(280, 130, 20, 14),
    Rect.fromLTWH(350, 60, 20, 14),
    Rect.fromLTWH(30, 170, 20, 14),
    Rect.fromLTWH(160, 170, 20, 14),
    Rect.fromLTWH(310, 170, 20, 14),
  ];
  static const _buildingRadius = Radius.circular(2);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _bgPaint);

    // 2. Grid lines
    const step = 40.0;
    for (double x = 0; x <= w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), _gridPaint);
    }
    for (double y = 0; y <= h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), _gridPaint);
    }

    // 3. Roads
    canvas.drawRect(Rect.fromLTWH(0, 90, w, 20), _roadPaint);
    canvas.drawRect(Rect.fromLTWH(180, 0, 20, h), _roadPaint);
    canvas.drawRect(Rect.fromLTWH(60, 0, 12, h), _roadPaint);
    canvas.drawRect(Rect.fromLTWH(320, 0, 12, h), _roadPaint);
    canvas.drawRect(Rect.fromLTWH(0, 30, w, 10), _roadPaint);
    canvas.drawRect(Rect.fromLTWH(0, 155, w, 10), _roadPaint);

    // 4. Dashed lane markings
    for (double x = 0; x < w; x += 30) {
      canvas.drawRect(Rect.fromLTWH(x, 99, 20, 2), _dashPaint);
    }

    // 5. Buildings
    for (final rect in _buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, _buildingRadius),
        _buildingPaint,
      );
    }

    // 6. Route (only when requested)
    if (showRoute) {
      final path = Path()
        ..moveTo(80, 160)
        ..cubicTo(150, 140, 200, 100, 260, 80)
        ..cubicTo(280, 72, 310, 60, 330, 55);
      canvas.drawPath(path, _routePaint);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.showRoute != showRoute;
}
