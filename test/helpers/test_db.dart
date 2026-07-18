import 'package:kjc_7day_chat/infrastructure/db/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return AppDatabase.open(inMemoryDatabasePath);
}
