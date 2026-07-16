import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class RoutePainter extends CustomPainter {
  final List<Offset> points;
  final List<int> segmentEnds;
  final int completedNodesCount;

  RoutePainter({
    required this.points,
    required this.segmentEnds,
    this.completedNodesCount = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    int splitIndex = 0;
    if (completedNodesCount > 0 && segmentEnds.isNotEmpty) {
      int safeIndex = completedNodesCount - 1;
      if (safeIndex >= segmentEnds.length) safeIndex = segmentEnds.length - 1;
      splitIndex = segmentEnds[safeIndex];
    }
    Set<String> fadedEdges = {};
    bool hasFaded = splitIndex > 0;

    if (hasFaded) {
      final fadedPath = Path();
      fadedPath.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < splitIndex; i++) {
        fadedPath.lineTo(points[i + 1].dx, points[i + 1].dy);
        String e1 = "${points[i].dx},${points[i].dy}-${points[i+1].dx},${points[i+1].dy}";
        String e2 = "${points[i+1].dx},${points[i+1].dy}-${points[i].dx},${points[i].dy}";
        fadedEdges.add(e1);
        fadedEdges.add(e2);
      }

      final fadedPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(fadedPath, fadedPaint);
    }

    final activePath = Path();
    bool pathBroken = true;
    bool hasActive = false;

    for (int i = splitIndex; i < points.length - 1; i++) {
      String edge = "${points[i].dx},${points[i].dy}-${points[i+1].dx},${points[i+1].dy}";
      if (!fadedEdges.contains(edge)) {
        hasActive = true;
        if (pathBroken) {
          activePath.moveTo(points[i].dx, points[i].dy);
          pathBroken = false;
        }
        activePath.lineTo(points[i+1].dx, points[i+1].dy);
      } else {
        pathBroken = true;
      }
    }

    if (hasActive) {
      final glowPaint = Paint()
        ..color = const Color(0xFF6200EA).withOpacity(0.35)
        ..strokeWidth = 14.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(activePath, glowPaint);
      final paint = Paint()
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      paint.shader = ui.Gradient.linear(
        points[splitIndex], points.last,
        [const Color(0xFF6200EA), const Color(0xFF00B4DB)],
      );
      canvas.drawPath(activePath, paint);
    }

    final startPaint = Paint()..color = Colors.green;
    final endPaint = Paint()..color = Colors.blue;
    final activeTargetPaint = Paint()..color = Colors.redAccent;
    final completedPaint = Paint()..color = Colors.grey.shade400;
    final innerWhite = Paint()..color = Colors.white;

    canvas.drawCircle(points.first, 10, startPaint);
    canvas.drawCircle(points.first, 4, innerWhite);

    for (int i = 0; i < segmentEnds.length; i++) {
      int nodeIndex = segmentEnds[i];
      if (nodeIndex <= 0 || nodeIndex >= points.length) continue;

      bool isCompleted = i < completedNodesCount;
      bool isActive = i == completedNodesCount;

      Paint markerPaint = isCompleted ? completedPaint : (isActive ? activeTargetPaint : endPaint);
      double radius = isActive ? 10.0 : 8.0;

      canvas.drawCircle(points[nodeIndex], radius, markerPaint);
      if (isActive) {
        canvas.drawCircle(points[nodeIndex], 4, innerWhite);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) => true;
}