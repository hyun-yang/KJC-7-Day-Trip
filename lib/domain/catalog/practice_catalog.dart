import '../entities/country.dart';
import '../entities/tourist_place.dart';

/// A country-specific cluster of three useful situations shown in Practice.
class PracticeGroup {
  PracticeGroup({
    required this.id,
    required this.labelEn,
    required List<RecommendedScene> scenes,
  }) : scenes = List<RecommendedScene>.unmodifiable(scenes) {
    if (scenes.length != 3) {
      throw ArgumentError.value(
        scenes.length,
        'scenes',
        'A practice group must have exactly three scenes.',
      );
    }
  }

  final String id;
  final String labelEn;
  final List<RecommendedScene> scenes;
}

RecommendedScene _scene(String categoryId, String subtopicId, String labelEn) =>
    RecommendedScene(
      categoryId: categoryId,
      subtopicId: subtopicId,
      labelEn: labelEn,
    );

PracticeGroup _group(
  String id,
  String labelEn,
  List<RecommendedScene> scenes,
) => PracticeGroup(id: id, labelEn: labelEn, scenes: scenes);

final Map<Country, List<PracticeGroup>> _practiceGroups =
    Map<Country, List<PracticeGroup>>.unmodifiable({
      Country.korea: List<PracticeGroup>.unmodifiable([
        _group('cafe-dining', 'Cafés & casual dining', [
          _scene('restaurant', 'cafe', 'Café'),
          _scene('restaurant', 'ordering', 'Ordering'),
          _scene('restaurant', 'paying', 'Paying'),
        ]),
        _group('transit', 'Subway & city transport', [
          _scene('transport', 'subway', 'Subway'),
          _scene('transport', 'bus', 'Bus'),
          _scene('transport', 'taxi', 'Taxi'),
        ]),
        _group('markets', 'Markets & shopping', [
          _scene('shopping', 'finding-shops', 'Finding shops'),
          _scene('shopping', 'phrases', 'Common shopping phrases'),
          _scene('shopping', 'paying', 'Paying'),
        ]),
        _group('neighborhoods', 'Neighbourhoods & sights', [
          _scene('sightseeing', 'directions', 'Asking for directions'),
          _scene('sightseeing', 'at-the-sights', 'At the sights'),
          _scene('sightseeing', 'photos', 'Photos & video'),
        ]),
        _group('help', 'Everyday help', [
          _scene('basics', 'requesting', 'Making requests'),
          _scene('facilities', 'restroom', 'Restroom'),
          _scene('emergency', 'lost-stolen', 'Loss & theft'),
        ]),
      ]),
      Country.japan: List<PracticeGroup>.unmodifiable([
        _group('sights', 'Shrines & sightseeing', [
          _scene('sightseeing', 'at-the-sights', 'At the sights'),
          _scene('sightseeing', 'photos', 'Photos & video'),
          _scene('sightseeing', 'tourist-info', 'Tourist information center'),
        ]),
        _group('rail', 'Rail & station navigation', [
          _scene('transport', 'subway', 'Subway'),
          _scene('transport', 'train', 'Train'),
          _scene('sightseeing', 'directions', 'Asking for directions'),
        ]),
        _group('food', 'Sushi, izakaya & cafés', [
          _scene('restaurant', 'izakaya', 'Sushi bar / izakaya / pub'),
          _scene('restaurant', 'ordering', 'Ordering'),
          _scene('restaurant', 'cafe', 'Café'),
        ]),
        _group('shops', 'Convenience stores & shopping', [
          _scene('shopping', 'convenience-store', 'Convenience store'),
          _scene('shopping', 'phrases', 'Common shopping phrases'),
          _scene('shopping', 'paying', 'Paying'),
        ]),
        _group('help', 'Courtesy & urgent help', [
          _scene('basics', 'requesting', 'Making requests'),
          _scene('emergency', 'lost-stolen', 'Loss & theft'),
          _scene('emergency', 'health', 'Health problems'),
        ]),
      ]),
      Country.china: List<PracticeGroup>.unmodifiable([
        _group('taxi-transit', 'Taxis & city transport', [
          _scene('transport', 'taxi', 'Taxi'),
          _scene('transport', 'subway', 'Subway'),
          _scene('transport', 'bus', 'Bus'),
        ]),
        _group('sights', 'Historic sights & tickets', [
          _scene('sightseeing', 'at-the-sights', 'At the sights'),
          _scene('sightseeing', 'tourist-info', 'Tourist information center'),
          _scene('sightseeing', 'photos', 'Photos & video'),
        ]),
        _group('restaurants', 'Restaurants & tea', [
          _scene('restaurant', 'menu', 'Choosing from the menu'),
          _scene('restaurant', 'ordering', 'Ordering'),
          _scene('restaurant', 'paying', 'Paying'),
        ]),
        _group('markets', 'Markets & bargaining', [
          _scene('shopping', 'finding-shops', 'Finding shops'),
          _scene('shopping', 'bargaining', 'Bargaining'),
          _scene('shopping', 'paying', 'Paying'),
        ]),
        _group('help', 'Directions & practical help', [
          _scene('sightseeing', 'directions', 'Asking for directions'),
          _scene('facilities', 'restroom', 'Restroom'),
          _scene('emergency', 'lost-stolen', 'Loss & theft'),
        ]),
      ]),
    });

/// Returns the immutable five-group Practice catalog for [country].
List<PracticeGroup> practiceGroupsFor(Country country) =>
    _practiceGroups[country]!;
