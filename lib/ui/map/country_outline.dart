import 'dart:ui';

/// A country outline represented by normalized polygons and its geographic
/// bounding box.
class CountryOutline {
  const CountryOutline({
    required this.aspect,
    required this.latNorth,
    required this.latSouth,
    required this.lngWest,
    required this.lngEast,
    required this.polygons,
  });

  /// Geographic width-to-height ratio, corrected for latitude.
  final double aspect;

  final double latNorth;
  final double latSouth;
  final double lngWest;
  final double lngEast;

  /// Normalized points: x runs west to east and y runs north to south.
  final List<List<Offset>> polygons;

  /// Converts a real latitude and longitude into normalized map coordinates.
  Offset normalize(double lat, double lng) => Offset(
    (lng - lngWest) / (lngEast - lngWest),
    (latNorth - lat) / (latNorth - latSouth),
  );
}
