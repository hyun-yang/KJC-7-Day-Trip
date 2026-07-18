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
  test(
    'conversation survives closing and reopening the same database file',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp('kjc_reopen_');
      final databasePath = path.join(directory.path, 'kjc.db');
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });

      var database = await AppDatabase.open(databasePath);
      final repository = ConversationRepository(database);
      final olderId = await repository.insert(
        _conversation(
          cityName: 'Tokyo',
          situation: 'Older',
          createdAt: DateTime.utc(2026, 7, 17),
        ),
        _lines,
      );
      final sameTimeFirstId = await repository.insert(
        _conversation(
          cityName: 'Kyoto',
          situation: 'Same time first',
          createdAt: DateTime.utc(2026, 7, 18),
        ),
        _lines,
      );
      final id = await repository.insert(
        _conversation(
          cityName: 'Osaka',
          situation: 'Same time second',
          createdAt: DateTime.utc(2026, 7, 18),
        ),
        _lines,
      );
      await database.close();

      database = await AppDatabase.open(databasePath);
      final reopened = ConversationRepository(database);
      final listed = await reopened.listAll();
      final loaded = await reopened.load(id);

      expect(listed.map((item) => item.id), [id, sameTimeFirstId, olderId]);
      expect(listed.map((item) => item.subtopicLabel), [
        'Same time second',
        'Same time first',
        'Older',
      ]);
      expect(loaded.conversation.cityName, 'Osaka');
      expect(loaded.lines.single.targetText, 'チェックインをお願いします。');
      await database.close();
    },
  );
}

Conversation _conversation({
  required String cityName,
  required String situation,
  required DateTime createdAt,
}) => Conversation(
  country: Country.japan,
  cityId: 11,
  cityName: cityName,
  categoryId: 'hotel',
  subtopicId: 'check-in',
  subtopicLabel: situation,
  nativeLang: NativeLanguage.english,
  model: 'gpt-test',
  createdAt: createdAt,
);

const _lines = [
  ConvLine(
    lineOrder: 0,
    speaker: 1,
    targetText: 'チェックインをお願いします。',
    romanization: 'Chekkuin o onegaishimasu.',
    transliteration: 'Check in, please.',
    translation: 'Check in, please.',
  ),
];
