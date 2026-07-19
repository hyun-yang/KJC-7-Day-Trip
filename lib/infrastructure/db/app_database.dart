import 'package:sqflite/sqflite.dart';
import '../seed/cities_seed.dart';
import 'row_mappers.dart';

class AppDatabase {
  static Future<Database> open(String path) => openDatabase(
    path,
    version: 2,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: _create,
    onUpgrade: _upgrade,
  );
  static Future<void> _create(Database db, int version) async {
    await db.execute(
      'CREATE TABLE cities (id INTEGER PRIMARY KEY, country TEXT NOT NULL, name_en TEXT NOT NULL, name_local TEXT NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, country TEXT NOT NULL, city_id INTEGER NOT NULL, city_name TEXT NOT NULL, category_id TEXT NOT NULL, subtopic_id TEXT NOT NULL, subtopic_label TEXT NOT NULL, native_lang TEXT NOT NULL, model TEXT NOT NULL, created_at TEXT NOT NULL, place_id INTEGER, place_name TEXT)',
    );
    await db.execute(
      'CREATE TABLE lines (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, line_order INTEGER NOT NULL, speaker INTEGER NOT NULL, target_text TEXT NOT NULL, romanization TEXT NOT NULL, transliteration TEXT NOT NULL, translation TEXT NOT NULL)',
    );
    final batch = db.batch();
    for (final city in citiesSeed) {
      batch.insert('cities', cityToRow(city));
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE conversations ADD COLUMN place_id INTEGER');
      await db.execute('ALTER TABLE conversations ADD COLUMN place_name TEXT');
    }
  }
}
