import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class RoutePainter extends CustomPainter {
  final List<Offset> points;
  final int completedNodesCount;

  RoutePainter({required this.points, this.completedNodesCount = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF6200EA).withOpacity(0.35)
      ..strokeWidth = 14.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round  // Rounded corners
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(path, glowPaint);

    final paint = Paint()
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    paint.shader = ui.Gradient.linear(
      points.first,
      points.last,
      [const Color(0xFF6200EA), const Color(0xFF00B4DB)],
    );

    canvas.drawPath(path, paint);

    final startPaint = Paint()..color = Colors.green;
    final endPaint = Paint()..color = Colors.blue;
    final activeTargetPaint = Paint()..color = Colors.redAccent;
    final completedPaint = Paint()..color = Colors.grey;
    final innerWhite = Paint()..color = Colors.white;

    canvas.drawCircle(points.first, 8, startPaint);
    int targetIndex = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy != 480.0) {

        targetIndex++;
        bool isCompleted = targetIndex <= completedNodesCount;
        bool isActive = targetIndex == completedNodesCount + 1;

        Paint markerPaint = isCompleted ? completedPaint : (isActive ? activeTargetPaint : endPaint);
        double radius = isActive ? 10.0 : 8.0;
        canvas.drawCircle(points[i], radius, markerPaint);

        if (isActive) {
          canvas.drawCircle(points[i], 4, innerWhite);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.completedNodesCount != completedNodesCount ||
        oldDelegate.points.length != points.length;
  }
}