import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  test('Travel illustration contains three flag-filled maps in order', () {
    final source = File(
      'assets/illustrations/journey_line_splash.svg',
    ).readAsStringSync();
    final korea = source.indexOf('id="korea-map"');
    final japan = source.indexOf('id="japan-map"');
    final china = source.indexOf('id="china-map"');

    expect(korea, greaterThanOrEqualTo(0));
    expect(japan, greaterThan(korea));
    expect(china, greaterThan(japan));
    expect(source, contains('id="korea-flag"'));
    expect(source, contains('id="korea-taegeuk-red"'));
    expect(source, contains('id="korea-taegeuk-blue"'));
    expect(source, contains('id="japan-flag"'));
    expect(source, contains('id="japan-sun"'));
    expect(source, contains('id="china-flag"'));
    expect(source, contains('id="china-stars"'));
    expect(source, contains('clip-path="url(#korea-map)"'));
    expect(source, contains('clip-path="url(#japan-map)"'));
    expect(source, contains('clip-path="url(#china-map)"'));
  });

  test('Korean trigrams and Chinese stars keep their flag structure', () {
    final source = File(
      'assets/illustrations/journey_line_splash.svg',
    ).readAsStringSync();

    expect(source, contains('id="korea-geon" data-pattern="111"'));
    expect(source, contains('id="korea-gon" data-pattern="000"'));
    expect(source, contains('id="korea-gam" data-pattern="010"'));
    expect(source, contains('id="korea-ri" data-pattern="101"'));
    expect(
      RegExp(r'id="china-star-(?:main|[1-4])"').allMatches(source),
      hasLength(5),
    );
    expect(
      RegExp(r'data-points-to="#china-star-main"').allMatches(source),
      hasLength(4),
    );
  });

  for (final width in [320.0, 200.0]) {
    testWidgets('flag maps match the approved ${width.toInt()}px artwork', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: width,
                child: AspectRatio(
                  aspectRatio: 390 / 280,
                  child: SvgPicture.asset(
                    'assets/illustrations/journey_line_splash.svg',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(SvgPicture),
        matchesGoldenFile('goldens/travel_flag_maps_${width.toInt()}.png'),
      );
    });
  }
}
