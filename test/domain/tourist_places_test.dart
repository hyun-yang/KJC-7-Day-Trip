import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/domain/entities/tourist_place.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/infrastructure/seed/tourist_places_seed.dart';
import 'package:kjc_7day_chat/infrastructure/tourist_place_repository.dart';

List<RecommendedScene> _scenes(int count) => List.generate(
  count,
  (index) => RecommendedScene(
    categoryId: 'category-$index',
    subtopicId: 'subtopic-$index',
    labelEn: 'Scene $index',
  ),
);

TouristPlace _placeWith(List<RecommendedScene> scenes) => TouristPlace(
  id: 1,
  cityId: 1,
  nameEn: 'Place',
  nameLocal: 'Place',
  descriptionEn: 'Description',
  mapX: 0.5,
  mapY: 0.5,
  recommendedScenes: scenes,
);

void main() {
  group('TouristPlace', () {
    test('rejects recommended scene counts other than three', () {
      expect(() => _placeWith(_scenes(2)), throwsArgumentError);
      expect(() => _placeWith(_scenes(4)), throwsArgumentError);
    });

    test('defensively copies and exposes unmodifiable recommendations', () {
      final scenes = _scenes(3);
      final place = _placeWith(scenes);

      scenes.removeLast();

      expect(place.recommendedScenes, hasLength(3));
      expect(
        () => place.recommendedScenes.removeLast(),
        throwsUnsupportedError,
      );
    });
  });

  group('tourist places catalog', () {
    test('contains five valid places for every seeded city', () {
      expect(touristPlacesSeed, hasLength(75));
      expect(touristPlacesSeed.map((place) => place.id).toSet(), hasLength(75));

      for (final city in citiesSeed) {
        final places = touristPlacesSeed
            .where((place) => place.cityId == city.id)
            .toList();
        expect(places, hasLength(5), reason: city.nameEn);
      }

      expect(
        touristPlacesSeed.map((place) => place.cityId).toSet(),
        citiesSeed.map((city) => city.id).toSet(),
      );
    });

    test('has complete display data and normalized map coordinates', () {
      for (final place in touristPlacesSeed) {
        expect(place.nameEn.trim(), isNotEmpty, reason: '${place.id} nameEn');
        expect(
          place.nameLocal.trim(),
          isNotEmpty,
          reason: '${place.id} nameLocal',
        );
        expect(
          place.descriptionEn.trim(),
          isNotEmpty,
          reason: '${place.id} descriptionEn',
        );
        expect(place.mapX, inInclusiveRange(0.0, 1.0), reason: '${place.id}');
        expect(place.mapY, inInclusiveRange(0.0, 1.0), reason: '${place.id}');
      }
    });

    test('has exactly three catalog-backed recommendations per place', () {
      for (final place in touristPlacesSeed) {
        expect(place.recommendedScenes, hasLength(3), reason: '${place.id}');
        for (final scene in place.recommendedScenes) {
          final subtopic = findSubtopic(scene.categoryId, scene.subtopicId);
          expect(scene.labelEn.trim(), isNotEmpty, reason: '${place.id}');
          expect(scene.labelEn, subtopic.labelEn, reason: '${place.id}');
        }
      }
    });

    test(
      'Tokyo uses the approved five-place Atlas set including Ueno Park',
      () {
        final tokyoPlaces = touristPlacesSeed
            .where((place) => place.cityId == 11)
            .toList(growable: false);

        expect(tokyoPlaces, hasLength(5));
        expect(
          tokyoPlaces.map((place) => place.nameEn),
          containsAll(<String>[
            'Senso-ji Temple',
            'Tokyo Skytree',
            'Shibuya Crossing',
            'Meiji Shrine',
            'Ueno Park',
          ]),
        );
        final ueno = tokyoPlaces.singleWhere(
          (place) => place.nameEn == 'Ueno Park',
        );
        expect(ueno.nameLocal, '上野公園');
        expect(ueno.descriptionEn, isNotEmpty);
      },
    );

    test('Tokyo recommendations reflect each approved place intent', () {
      final byName = <String, TouristPlace>{
        for (final place in touristPlacesSeed.where(
          (place) => place.cityId == 11,
        ))
          place.nameEn: place,
      };
      List<String> ids(String name) => byName[name]!.recommendedScenes
          .map((scene) => '${scene.categoryId}/${scene.subtopicId}')
          .toList(growable: false);

      expect(ids('Senso-ji Temple'), [
        'sightseeing/at-the-sights',
        'basics/asking',
        'shopping/phrases',
      ]);
      expect(ids('Tokyo Skytree'), [
        'sightseeing/at-the-sights',
        'sightseeing/tourist-info',
        'sightseeing/photos',
      ]);
      expect(ids('Shibuya Crossing'), [
        'sightseeing/directions',
        'basics/confirming',
        'emergency/lost-stolen',
      ]);
      expect(ids('Meiji Shrine'), [
        'basics/asking',
        'shopping/phrases',
        'sightseeing/tourist-info',
      ]);
      expect(ids('Ueno Park'), [
        'sightseeing/tourist-info',
        'sightseeing/at-the-sights',
        'facilities/restroom',
      ]);
    });

    test('catalog uses a diverse set of attraction recommendations', () {
      final triples = touristPlacesSeed
          .map(
            (place) => place.recommendedScenes
                .map((scene) => '${scene.categoryId}/${scene.subtopicId}')
                .join('|'),
          )
          .toSet();

      expect(triples.length, greaterThanOrEqualTo(8));
    });

    test('is unmodifiable', () {
      expect(() => touristPlacesSeed.removeLast(), throwsUnsupportedError);
    });
  });

  group('TouristPlaceRepository', () {
    final repository = TouristPlaceRepository();

    test('lists only places in the requested city', () {
      final places = repository.listByCity(11);

      expect(places, hasLength(5));
      expect(places.every((place) => place.cityId == 11), isTrue);
    });

    test('returns an unmodifiable list', () {
      final places = repository.listByCity(11);

      expect(() => places.removeLast(), throwsUnsupportedError);
    });

    test('rejects an injected place with an unknown catalog reference', () {
      final invalid = _placeWith(const [
        RecommendedScene(
          categoryId: 'unknown',
          subtopicId: 'missing',
          labelEn: 'Missing',
        ),
        RecommendedScene(
          categoryId: 'sightseeing',
          subtopicId: 'photos',
          labelEn: 'Photos & video',
        ),
        RecommendedScene(
          categoryId: 'facilities',
          subtopicId: 'restroom',
          labelEn: 'Restroom',
        ),
      ]);

      expect(
        () => TouristPlaceRepository(places: [invalid]),
        throwsArgumentError,
      );
    });

    test('rejects an injected scene label that differs from the catalog', () {
      final invalid = _placeWith(const [
        RecommendedScene(
          categoryId: 'sightseeing',
          subtopicId: 'at-the-sights',
          labelEn: 'Wrong label',
        ),
        RecommendedScene(
          categoryId: 'sightseeing',
          subtopicId: 'photos',
          labelEn: 'Photos & video',
        ),
        RecommendedScene(
          categoryId: 'facilities',
          subtopicId: 'restroom',
          labelEn: 'Restroom',
        ),
      ]);

      expect(
        () => TouristPlaceRepository(places: [invalid]),
        throwsArgumentError,
      );
    });
  });
}
