import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const assets = [
    'assets/illustrations/atlas_postcard_splash.svg',
    'assets/illustrations/cultural_seals_splash.svg',
    'assets/illustrations/journey_line_splash.svg',
  ];

  test('ships three text-free East Asia splash SVG concepts', () {
    for (final asset in assets) {
      final source = File(asset).readAsStringSync();
      expect(source, contains('<svg'));
      expect(source, contains('viewBox="0 0 390 280"'));
      expect(source, isNot(contains('<text')));
    }
  });
}
