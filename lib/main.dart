import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'infrastructure/db/app_database.dart';
import 'infrastructure/settings/settings_repository.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final supportDir = await getApplicationSupportDirectory();
  final database = await AppDatabase.open(p.join(supportDir.path, 'kjc.db'));
  final settingsDir = Directory(p.join(supportDir.path, 'settings'));
  final settings = await SettingsRepository(settingsDir).load();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsDirProvider.overrideWithValue(settingsDir),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const KjcApp(),
    ),
  );
}
