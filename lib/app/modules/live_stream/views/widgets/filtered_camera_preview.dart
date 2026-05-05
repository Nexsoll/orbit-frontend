// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/stream_filter_model.dart';
import '../../controllers/stream_filter_controller.dart';

class FilteredCameraPreview extends StatelessWidget {
  final Widget child;
  final StreamFilterController filterController;

  const FilteredCameraPreview({
    super.key,
    required this.child,
    required this.filterController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: filterController,
      builder: (context, _) {
        Widget filteredChild = child;

        // Apply color filter if active
        if (filterController.currentFilter.filterType != FilterType.none) {
          filteredChild = ColorFiltered(
            colorFilter: ColorFilter.matrix(filterController.getColorMatrix()),
            child: filteredChild,
          );
        }

        // Apply face filter overlay if active
        if (filterController.currentFilter.faceFilterType !=
            FaceFilterType.none) {
          filteredChild = Stack(
            children: [
              filteredChild,
              _buildFaceFilterOverlay(
                  filterController.currentFilter.faceFilterType),
            ],
          );
        }

        // Apply blur effect if selected
        if (filterController.currentFilter.filterType == FilterType.blur) {
          filteredChild = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 2.0 * filterController.currentFilter.intensity,
              sigmaY: 2.0 * filterController.currentFilter.intensity,
            ),
            child: filteredChild,
          );
        }

        return filteredChild;
      },
    );
  }

  Widget _buildFaceFilterOverlay(FaceFilterType faceFilterType) {
    return Positioned.fill(
      child: CustomPaint(
        painter: FaceFilterPainter(faceFilterType),
      ),
    );
  }
}

class FaceFilterPainter extends CustomPainter {
  final FaceFilterType faceFilterType;

  FaceFilterPainter(this.faceFilterType);

  @override
  void paint(Canvas canvas, Size size) {
    // This is a simplified implementation
    // In a real app, you would use face detection to position these elements
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (faceFilterType) {
      case FaceFilterType.dogEars:
        _drawDogEars(canvas, centerX, centerY - 100);
        break;
      case FaceFilterType.catEars:
        _drawCatEars(canvas, centerX, centerY - 100);
        break;
      case FaceFilterType.bunnyEars:
        _drawBunnyEars(canvas, centerX, centerY - 100);
        break;
      case FaceFilterType.crown:
        _drawCrown(canvas, centerX, centerY - 120);
        break;
      case FaceFilterType.glasses:
        _drawGlasses(canvas, centerX, centerY - 20);
        break;
      case FaceFilterType.mustache:
        _drawMustache(canvas, centerX, centerY + 20);
        break;
      case FaceFilterType.heart:
        _drawHeartEyes(canvas, centerX, centerY - 20);
        break;
      case FaceFilterType.flower:
        _drawFlowerCrown(canvas, centerX, centerY - 100);
        break;
      case FaceFilterType.none:
        break;
    }
  }

  void _drawDogEars(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    // Left ear
    final leftEarPath = Path()
      ..moveTo(centerX - 60, centerY)
      ..lineTo(centerX - 40, centerY - 40)
      ..lineTo(centerX - 20, centerY - 10)
      ..close();

    // Right ear
    final rightEarPath = Path()
      ..moveTo(centerX + 60, centerY)
      ..lineTo(centerX + 40, centerY - 40)
      ..lineTo(centerX + 20, centerY - 10)
      ..close();

    canvas.drawPath(leftEarPath, paint);
    canvas.drawPath(rightEarPath, paint);
  }

  void _drawCatEars(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFF696969)
      ..style = PaintingStyle.fill;

    // Left ear
    final leftEarPath = Path()
      ..moveTo(centerX - 50, centerY)
      ..lineTo(centerX - 30, centerY - 50)
      ..lineTo(centerX - 10, centerY - 10)
      ..close();

    // Right ear
    final rightEarPath = Path()
      ..moveTo(centerX + 50, centerY)
      ..lineTo(centerX + 30, centerY - 50)
      ..lineTo(centerX + 10, centerY - 10)
      ..close();

    canvas.drawPath(leftEarPath, paint);
    canvas.drawPath(rightEarPath, paint);

    // Inner ears
    paint.color = const Color(0xFFFFB6C1);
    canvas.drawCircle(Offset(centerX - 30, centerY - 25), 8, paint);
    canvas.drawCircle(Offset(centerX + 30, centerY - 25), 8, paint);
  }

  void _drawBunnyEars(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    // Left ear
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - 40, centerY - 30),
        width: 20,
        height: 60,
      ),
      paint,
    );

    // Right ear
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + 40, centerY - 30),
        width: 20,
        height: 60,
      ),
      paint,
    );

    // Inner ears
    paint.color = const Color(0xFFFFB6C1);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - 40, centerY - 25),
        width: 10,
        height: 40,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + 40, centerY - 25),
        width: 10,
        height: 40,
      ),
      paint,
    );
  }

  void _drawCrown(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    final crownPath = Path()
      ..moveTo(centerX - 80, centerY + 20)
      ..lineTo(centerX - 60, centerY - 20)
      ..lineTo(centerX - 40, centerY + 10)
      ..lineTo(centerX - 20, centerY - 30)
      ..lineTo(centerX, centerY + 10)
      ..lineTo(centerX + 20, centerY - 30)
      ..lineTo(centerX + 40, centerY + 10)
      ..lineTo(centerX + 60, centerY - 20)
      ..lineTo(centerX + 80, centerY + 20)
      ..close();

    canvas.drawPath(crownPath, paint);

    // Gems
    paint.color = const Color(0xFFFF0000);
    canvas.drawCircle(Offset(centerX - 20, centerY - 10), 5, paint);
    canvas.drawCircle(Offset(centerX, centerY - 15), 6, paint);
    canvas.drawCircle(Offset(centerX + 20, centerY - 10), 5, paint);
  }

  void _drawGlasses(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Left lens
    canvas.drawCircle(Offset(centerX - 30, centerY), 25, paint);
    // Right lens
    canvas.drawCircle(Offset(centerX + 30, centerY), 25, paint);
    // Bridge
    canvas.drawLine(
      Offset(centerX - 5, centerY),
      Offset(centerX + 5, centerY),
      paint,
    );
    // Left temple
    canvas.drawLine(
      Offset(centerX - 55, centerY),
      Offset(centerX - 80, centerY - 10),
      paint,
    );
    // Right temple
    canvas.drawLine(
      Offset(centerX + 55, centerY),
      Offset(centerX + 80, centerY - 10),
      paint,
    );
  }

  void _drawMustache(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;

    final mustachePath = Path()
      ..moveTo(centerX - 30, centerY)
      ..quadraticBezierTo(centerX - 15, centerY - 15, centerX, centerY - 5)
      ..quadraticBezierTo(centerX + 15, centerY - 15, centerX + 30, centerY)
      ..quadraticBezierTo(centerX + 15, centerY + 10, centerX, centerY + 5)
      ..quadraticBezierTo(centerX - 15, centerY + 10, centerX - 30, centerY)
      ..close();

    canvas.drawPath(mustachePath, paint);
  }

  void _drawHeartEyes(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFFFF69B4)
      ..style = PaintingStyle.fill;

    // Left heart
    _drawHeart(canvas, Offset(centerX - 25, centerY), 15, paint);
    // Right heart
    _drawHeart(canvas, Offset(centerX + 25, centerY), 15, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final heartPath = Path()
      ..moveTo(center.dx, center.dy + size * 0.3)
      ..cubicTo(
        center.dx - size * 0.5,
        center.dy - size * 0.3,
        center.dx - size,
        center.dy + size * 0.1,
        center.dx,
        center.dy + size * 0.7,
      )
      ..cubicTo(
        center.dx + size,
        center.dy + size * 0.1,
        center.dx + size * 0.5,
        center.dy - size * 0.3,
        center.dx,
        center.dy + size * 0.3,
      )
      ..close();

    canvas.drawPath(heartPath, paint);
  }

  void _drawFlowerCrown(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = const Color(0xFFFF69B4)
      ..style = PaintingStyle.fill;

    // Draw multiple flowers
    for (int i = 0; i < 5; i++) {
      final x = centerX - 60 + (i * 30);
      final y = centerY + (i % 2 == 0 ? -10 : 0);
      _drawFlower(canvas, Offset(x, y), 12, paint);
    }
  }

  void _drawFlower(Canvas canvas, Offset center, double size, Paint paint) {
    // Petals
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (3.14159 / 180);
      final petalCenter = Offset(
        center.dx + (size * 0.7) * cos(angle),
        center.dy + (size * 0.7) * sin(angle),
      );
      canvas.drawCircle(petalCenter, size * 0.4, paint);
    }

    // Center
    paint.color = const Color(0xFFFFFF00);
    canvas.drawCircle(center, size * 0.3, paint);
    paint.color = const Color(0xFFFF69B4); // Reset color
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

double cos(double radians) => math.cos(radians);
double sin(double radians) => math.sin(radians);
