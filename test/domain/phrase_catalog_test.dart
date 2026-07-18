import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';

void main() {
  test('카탈로그: 11 카테고리 · 59 소주제 · id 유일', () {
    expect(kPhraseCatalog.length, 11);
    final subtopicCount = kPhraseCatalog.fold<int>(
      0,
      (count, category) => count + category.subtopics.length,
    );
    expect(subtopicCount, 59);
    final categoryIds = kPhraseCatalog.map((category) => category.id).toSet();
    expect(categoryIds.length, 11);
    for (final category in kPhraseCatalog) {
      final ids = category.subtopics.map((subtopic) => subtopic.id).toSet();
      expect(
        ids.length,
        category.subtopics.length,
        reason: '중복 id: ${category.id}',
      );
      for (final subtopic in category.subtopics) {
        expect(subtopic.promptHint, isNotEmpty);
      }
    }
  });

  test('findCategory/findSubtopic', () {
    expect(findCategory('hotel').labelEn, 'Hotel');
    expect(
      findSubtopic('hotel', 'check-in').labelEn,
      'Check-in (with or without a reservation)',
    );
    expect(() => findCategory('nope'), throwsArgumentError);
    expect(() => findSubtopic('hotel', 'nope'), throwsArgumentError);
  });
}
