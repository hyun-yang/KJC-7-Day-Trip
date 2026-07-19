import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/domain/catalog/practice_catalog.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';

void main() {
  group('practice catalog', () {
    test('has five groups and fifteen catalog-valid scenes per country', () {
      for (final country in Country.values) {
        final groups = practiceGroupsFor(country);
        expect(groups, hasLength(5), reason: country.labelEn);
        expect(
          groups.expand((group) => group.scenes),
          hasLength(15),
          reason: country.labelEn,
        );

        for (final group in groups) {
          expect(group.labelEn, isNotEmpty);
          expect(group.scenes, hasLength(3));
          for (final scene in group.scenes) {
            final category = findCategory(scene.categoryId);
            final subtopic = findSubtopic(scene.categoryId, scene.subtopicId);
            expect(scene.labelEn, subtopic.labelEn);
            expect(category.subtopics, contains(same(subtopic)));
          }
        }
      }
    });

    test('is immutable and diverse within every country', () {
      for (final country in Country.values) {
        final groups = practiceGroupsFor(country);
        expect(() => groups.add(groups.first), throwsUnsupportedError);
        expect(() => groups.first.scenes.clear(), throwsUnsupportedError);

        expect(groups.map((group) => group.id).toSet(), hasLength(5));
        expect(groups.map((group) => group.labelEn).toSet(), hasLength(5));
        final sceneKeys = groups
            .expand((group) => group.scenes)
            .map((scene) => '${scene.categoryId}/${scene.subtopicId}')
            .toSet();
        expect(sceneKeys.length, greaterThanOrEqualTo(10));
        expect(
          groups
              .expand((group) => group.scenes)
              .map((scene) => scene.categoryId)
              .toSet()
              .length,
          greaterThanOrEqualTo(4),
        );
      }
    });

    test('country catalogs have country-appropriate distinct group labels', () {
      final korea = practiceGroupsFor(
        Country.korea,
      ).map((group) => group.labelEn).toSet();
      final japan = practiceGroupsFor(
        Country.japan,
      ).map((group) => group.labelEn).toSet();
      final china = practiceGroupsFor(
        Country.china,
      ).map((group) => group.labelEn).toSet();

      expect(korea, contains('Cafés & casual dining'));
      expect(japan, contains('Shrines & sightseeing'));
      expect(china, contains('Taxis & city transport'));
      expect(korea, isNot(japan));
      expect(japan, isNot(china));
    });
  });
}
