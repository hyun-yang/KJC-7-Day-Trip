import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/ui/map/country_map_painter.dart';
import 'package:kjc_7day_chat/ui/map/country_outline.dart';
import 'package:kjc_7day_chat/ui/map/country_outlines_data.dart';

void main() {
  const outline = CountryOutline(
    aspect: 0.5,
    latNorth: 40,
    latSouth: 30,
    lngWest: 120,
    lngEast: 130,
    polygons: [
      [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)],
    ],
  );

  test('normalize maps bounding-box corners and center', () {
    expect(outline.normalize(40, 120), const Offset(0, 0));
    expect(outline.normalize(30, 130), const Offset(1, 1));
    expect(outline.normalize(35, 125), const Offset(0.5, 0.5));
  });

  test('project preserves aspect and centers the letterboxed map', () {
    const size = Size(200, 200);

    expect(
      CountryMapPainter.project(outline, const Offset(0, 0), size),
      const Offset(50, 0),
    );
    expect(
      CountryMapPainter.project(outline, const Offset(1, 1), size),
      const Offset(150, 200),
    );
  });

  test('generated outlines cover all three countries and all 15 cities', () {
    expect(kOutlineByCountry, hasLength(3));
    expect(citiesSeed, hasLength(15));
    expect(kKoreaOutline.polygons.length, greaterThanOrEqualTo(2));
    expect(kJapanOutline.polygons.length, greaterThanOrEqualTo(4));
    expect(
      kChinaOutline.polygons.length,
      greaterThanOrEqualTo(2),
      reason: 'China must retain Hainan in addition to the mainland',
    );

    var validatedCities = 0;
    for (final entry in kOutlineByCountry.entries) {
      final generated = entry.value;
      expect(generated.polygons, isNotEmpty, reason: entry.key.dbValue);
      expect(generated.aspect, greaterThan(0), reason: entry.key.dbValue);

      final pointCount = generated.polygons.fold<int>(
        0,
        (sum, polygon) => sum + polygon.length,
      );
      expect(
        pointCount,
        inInclusiveRange(100, 500),
        reason: '${entry.key.dbValue} generated point count',
      );

      for (final polygon in generated.polygons) {
        expect(polygon.length, greaterThanOrEqualTo(4));
        for (final point in polygon) {
          expect(point.dx, inInclusiveRange(0, 1));
          expect(point.dy, inInclusiveRange(0, 1));
        }
      }

      final countryCities = citiesSeed.where(
        (city) => city.country == entry.key,
      );
      expect(countryCities, hasLength(5), reason: entry.key.dbValue);
      for (final city in countryCities) {
        final norm = generated.normalize(city.lat, city.lng);
        expect(norm.dx, inInclusiveRange(0, 1), reason: city.nameEn);
        expect(norm.dy, inInclusiveRange(0, 1), reason: city.nameEn);
        validatedCities++;
      }
    }

    expect(validatedCities, 15);
  });
}
