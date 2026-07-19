import 'package:flutter/material.dart';

abstract final class AtlasTheme {
  static const background = Color(0xFFF8F5EF);
  static const paper = Color(0xFFFFFDF8);
  static const green = Color(0xFF0B5246);
  static const heading = Color(0xFF153C33);
  static const muted = Color(0xFF6F746E);
  static const line = Color(0xFFDDD9CF);
  static const pin = Color(0xFFC74832);
  static const selected = Color(0xFFF1F5EF);

  static const double pagePadding = 22;
  static const double minimumTarget = 48;
  static const double sheetRadius = 22;

  static const display = TextStyle(
    color: heading,
    fontFamily: 'serif',
    fontFamilyFallback: ['Noto Serif', 'Droid Serif', 'DejaVu Serif'],
    fontSize: 31,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const sectionTitle = TextStyle(
    color: heading,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const mutedBody = TextStyle(color: muted, fontSize: 14, height: 1.45);
}
