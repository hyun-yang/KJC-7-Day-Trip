import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/conversation.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/infrastructure/db/app_database.dart';
import 'package:kjc_7day_chat/infrastructure/db/conversation_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('v1 conversations migrate to v2 without losing rows or lines', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('kjc_migration_');
    final databasePath = path.join(directory.path, 'kjc.db');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    var database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, country TEXT NOT NULL, city_id INTEGER NOT NULL, city_name TEXT NOT NULL, category_id TEXT NOT NULL, subtopic_id TEXT NOT NULL, subtopic_label TEXT NOT NULL, native_lang TEXT NOT NULL, model TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE lines (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, line_order INTEGER NOT NULL, speaker INTEGER NOT NULL, target_text TEXT NOT NULL, romanization TEXT NOT NULL, transliteration TEXT NOT NULL, translation TEXT NOT NULL)',
        );
      },
    );
    final conversationId = await database.insert('conversations', {
      'country': 'JP',
      'city_id': 11,
      'city_name': 'Tokyo',
      'category_id': 'hotel',
      'subtopic_id': 'check-in',
      'subtopic_label': 'Check-in',
      'native_lang': 'en',
      'model': 'gpt-test',
      'created_at': DateTime.utc(2026, 7, 18).toIso8601String(),
    });
    await database.insert('lines', {
      'conversation_id': conversationId,
      'line_order': 0,
      'speaker': 1,
      'target_text': 'チェックインをお願いします。',
      'romanization': 'Chekkuin o onegaishimasu.',
      'transliteration': 'Check in, please.',
      'translation': 'Check in, please.',
    });
    await database.close();

    database = await AppDatabase.open(databasePath);
    addTearDown(database.close);
    expect(await database.getVersion(), 2);

    final repository = ConversationRepository(database);
    final migrated = await repository.load(conversationId);
    expect(migrated.conversation.cityName, 'Tokyo');
    expect(migrated.conversation.placeId, isNull);
    expect(migrated.conversation.placeName, isNull);
    expect(migrated.lines.single.targetText, 'チェックインをお願いします。');

    final placeAwareId = await repository.insert(
      Conversation(
        country: Country.japan,
        cityId: 11,
        cityName: 'Tokyo',
        categoryId: 'sightseeing',
        subtopicId: 'at-the-sights',
        subtopicLabel: 'At the sights',
        nativeLang: NativeLanguage.english,
        model: 'gpt-test',
        createdAt: DateTime.utc(2026, 7, 19),
        placeId: 1101,
        placeName: 'Senso-ji Temple',
      ),
      const [],
    );
    final placeAware = (await repository.load(placeAwareId)).conversation;
    expect(placeAware.placeId, 1101);
    expect(placeAware.placeName, 'Senso-ji Temple');
  });
}
