import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'country_outline.dart';

class CountryMapPainter extends CustomPainter {
  const CountryMapPainter(this.outline);

  final CountryOutline outline;

  /// Projects normalized coordinates while preserving the map's aspect ratio
  /// and centering any letterboxing in the available size.
  static Offset project(CountryOutline outline, Offset norm, Size size) {
    final mapHeight = math.min(size.height, size.width / outline.aspect);
    final mapWidth = mapHeight * outline.aspect;
    final origin = Offset(
      (size.width - mapWidth) / 2,
      (size.height - mapHeight) / 2,
    );
    return origin + Offset(norm.dx * mapWidth, norm.dy * mapHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFE8E0D8);
    final stroke = Paint()
      ..color = const Color(0xFF6B5E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final polygon in outline.polygons) {
      final path = Path()
        ..addPolygon([
          for (final point in polygon) project(outline, point, size),
        ], true);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CountryMapPainter oldDelegate) =>
      oldDelegate.outline != outline;
}
