import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/conversation.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/infrastructure/db/city_repository.dart';
import 'package:kjc_7day_chat/infrastructure/db/conversation_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  setUp(() async => db = await openTestDb());
  tearDown(() => db.close());

  test('cities 시드: 국가별 5개', () async {
    final repo = CityRepository(db);
    for (final country in Country.values) {
      final cities = await repo.listByCountry(country);
      expect(cities.length, 5, reason: country.dbValue);
      expect(cities.every((city) => city.country == country), isTrue);
    }
  });

  test('conversation insert → list → load → delete 왕복', () async {
    final repo = ConversationRepository(db);
    final id = await repo.insert(
      Conversation(
        country: Country.japan,
        cityId: 11,
        cityName: 'Tokyo',
        categoryId: 'hotel',
        subtopicId: 'check-in',
        subtopicLabel: 'Check-in (with or without a reservation)',
        nativeLang: NativeLanguage.korean,
        model: 'test-model',
        createdAt: DateTime.utc(2026, 7, 18),
      ),
      const [
        ConvLine(
          lineOrder: 0,
          speaker: 1,
          targetText: 'チェックインをお願いします。',
          romanization: 'chekkuin o onegaishimasu.',
          transliteration: '첵쿠인 오 오네가이시마스',
          translation: '체크인 부탁드립니다.',
        ),
        ConvLine(
          lineOrder: 1,
          speaker: 2,
          targetText: 'お名前をお願いします。',
          romanization: 'onamae o onegaishimasu.',
          transliteration: '오나마에 오 오네가이시마스',
          translation: '성함을 부탁드립니다.',
        ),
      ],
    );
    final list = await repo.listAll();
    expect(list.single.id, id);
    expect(list.single.country, Country.japan);
    expect(list.single.nativeLang, NativeLanguage.korean);
    final detail = await repo.load(id);
    expect(detail.lines.length, 2);
    expect(detail.lines.first.targetText, 'チェックインをお願いします。');
    expect(detail.lines.first.conversationId, id);
    await repo.delete(id);
    expect(await repo.listAll(), isEmpty);
    expect(await db.query('lines'), isEmpty);
  });
}
