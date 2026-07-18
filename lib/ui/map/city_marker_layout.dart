import 'dart:math' as math;
import 'dart:ui';

import '../../domain/entities/city.dart';
import 'country_map_painter.dart';
import 'country_outline.dart';

const kCityMarkerTouchSize = 48.0;

class CityMarkerPlacement {
  const CityMarkerPlacement({
    required this.city,
    required this.anchor,
    required this.center,
    required this.touchSize,
  });

  final City city;
  final Offset anchor;
  final Offset center;
  final double touchSize;

  Rect get rect =>
      Rect.fromCenter(center: center, width: touchSize, height: touchSize);
}

/// Keeps each marker connected to its true projected [anchor], while moving
/// crowded touch targets to the nearest deterministic, non-overlapping spot.
List<CityMarkerPlacement> layoutCityMarkers({
  required CountryOutline outline,
  required List<City> cities,
  required Size size,
  double touchSize = kCityMarkerTouchSize,
  double gap = 4,
}) {
  if (size.width < touchSize || size.height < touchSize) {
    throw ArgumentError('Map is smaller than a city marker touch target.');
  }

  final placements = <CityMarkerPlacement>[];
  for (final city in cities) {
    final normalized = outline.normalize(city.lat, city.lng);
    final anchor = CountryMapPainter.project(outline, normalized, size);
    final desired = _clampCenter(anchor, size, touchSize);
    final candidates = _candidateCenters(desired, size, touchSize, gap)
      ..sort((first, second) {
        final distanceOrder = _distanceSquared(
          first,
          desired,
        ).compareTo(_distanceSquared(second, desired));
        if (distanceOrder != 0) return distanceOrder;
        final verticalOrder = first.dy.compareTo(second.dy);
        return verticalOrder != 0
            ? verticalOrder
            : first.dx.compareTo(second.dx);
      });

    Offset? selected;
    for (final candidate in candidates) {
      final rect = Rect.fromCenter(
        center: candidate,
        width: touchSize,
        height: touchSize,
      );
      if (placements.every(
        (placed) =>
            !rect.inflate(gap / 2).overlaps(placed.rect.inflate(gap / 2)),
      )) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) {
      throw StateError('No marker position available for ${city.nameEn}.');
    }
    placements.add(
      CityMarkerPlacement(
        city: city,
        anchor: anchor,
        center: selected,
        touchSize: touchSize,
      ),
    );
  }
  return placements;
}

List<Offset> _candidateCenters(
  Offset desired,
  Size size,
  double touchSize,
  double gap,
) {
  final step = touchSize + gap;
  final candidates = <Offset>[desired];
  final seen = <String>{};

  void add(Offset candidate) {
    final clamped = _clampCenter(candidate, size, touchSize);
    final key =
        '${clamped.dx.toStringAsFixed(3)}:'
        '${clamped.dy.toStringAsFixed(3)}';
    if (seen.add(key)) candidates.add(clamped);
  }

  for (var ring = 1; ring <= 6; ring++) {
    for (var y = -ring; y <= ring; y++) {
      for (var x = -ring; x <= ring; x++) {
        if (x.abs() != ring && y.abs() != ring) continue;
        add(desired + Offset(x * step, y * step));
      }
    }
  }

  final half = touchSize / 2;
  for (var y = half; y <= size.height - half; y += step) {
    for (var x = half; x <= size.width - half; x += step) {
      add(Offset(x, y));
    }
  }
  add(Offset(size.width - half, size.height - half));
  add(Offset(half, size.height - half));
  add(Offset(size.width - half, half));
  return candidates;
}

Offset _clampCenter(Offset center, Size size, double touchSize) {
  final half = touchSize / 2;
  return Offset(
    center.dx.clamp(half, math.max(half, size.width - half)).toDouble(),
    center.dy.clamp(half, math.max(half, size.height - half)).toDouble(),
  );
}

double _distanceSquared(Offset first, Offset second) {
  final dx = first.dx - second.dx;
  final dy = first.dy - second.dy;
  return dx * dx + dy * dy;
}
