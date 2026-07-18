import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/settings/kjc_settings.dart';

class SettingsRepository {
  SettingsRepository(this._dir);

  final Directory _dir;

  File get _file => File(p.join(_dir.path, 'settings.json'));

  Future<KjcSettings> load() async {
    try {
      if (!_file.existsSync()) return const KjcSettings();

      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map<String, Object?>) return const KjcSettings();

      return KjcSettings.fromJson(decoded);
    } catch (_) {
      return const KjcSettings();
    }
  }

  Future<void> save(KjcSettings settings) async {
    _dir.createSync(recursive: true);
    _file.writeAsStringSync(jsonEncode(settings.toJson()));
  }
}
