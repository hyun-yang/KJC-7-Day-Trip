import '../domain/catalog/phrase_catalog.dart';
import '../domain/entities/tourist_place.dart';
import 'seed/tourist_places_seed.dart';

class TouristPlaceRepository {
  TouristPlaceRepository({List<TouristPlace>? places})
    : _places = List.unmodifiable(places ?? touristPlacesSeed) {
    for (final place in _places) {
      for (final scene in place.recommendedScenes) {
        late final Subtopic subtopic;
        try {
          subtopic = findSubtopic(scene.categoryId, scene.subtopicId);
        } on ArgumentError catch (error) {
          throw ArgumentError.value(
            '${scene.categoryId}/${scene.subtopicId}',
            'places',
            'Tourist place ${place.id} has an invalid scene reference: '
                '$error',
          );
        }
        if (scene.labelEn != subtopic.labelEn) {
          throw ArgumentError.value(
            scene.labelEn,
            'places',
            'Tourist place ${place.id} scene label must be '
                '${subtopic.labelEn}.',
          );
        }
      }
    }
  }

  final List<TouristPlace> _places;

  List<TouristPlace> listByCity(int cityId) =>
      List.unmodifiable(_places.where((place) => place.cityId == cityId));
}
