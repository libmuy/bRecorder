import 'package:flutter/material.dart';


class CenterBarPainter extends CustomPainter {
  Paint painter = Paint();
  final Color color;
  final double strokeWidth;
  final double barWidth;

  CenterBarPainter({
    this.strokeWidth = 10.0,
    this.color = Colors.red,
    this.barWidth = 0.5,
  }) {
    painter = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    double center = size.width / 2;
    double circleRadius = center;

    canvas.drawRect(
        Rect.fromLTWH(center - barWidth, circleRadius, barWidth,
            size.height - (circleRadius * 2)),
        painter);
    canvas.drawCircle(Offset(center, circleRadius), circleRadius, painter);
    canvas.drawCircle(
        Offset(center, size.height - circleRadius), circleRadius, painter);
  }

  @override
  bool shouldRepaint(CenterBarPainter oldDelegate) {
    if (oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth) {
      // debugPrint("Redrawing");
      return true;
    }
    return false;
  }
}
