import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/settings/kjc_settings.dart';
import 'package:kjc_7day_chat/infrastructure/settings/api_key_store.dart';
import 'package:kjc_7day_chat/infrastructure/settings/settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('kjc_settings'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('save and load round-trip settings', () async {
      final repo = SettingsRepository(dir);
      await repo.save(
        const KjcSettings(
          nativeLanguage: NativeLanguage.french,
          openaiModel: 'gpt-5.4-nano',
        ),
      );

      final loaded = await repo.load();

      expect(loaded.nativeLanguage, NativeLanguage.french);
      expect(loaded.openaiModel, 'gpt-5.4-nano');
    });

    test('missing or broken JSON returns defaults', () async {
      final repo = SettingsRepository(dir);

      expect((await repo.load()).nativeLanguage, NativeLanguage.english);

      File('${dir.path}/settings.json').writeAsStringSync('{broken');
      final loaded = await repo.load();

      expect(loaded.nativeLanguage, NativeLanguage.english);
      expect(loaded.openaiModel, kDefaultOpenAiModel);
    });
  });

  group('ApiKeyStore', () {
    test('in-memory store trims keys and empty input deletes them', () async {
      final store = InMemoryApiKeyStore();

      await store.write('  secret-key  ');
      expect(await store.read(), 'secret-key');

      await store.write('   ');
      expect(await store.read(), isNull);
    });

    test(
      'secure store uses the OpenAI key, trims, and deletes empty input',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        const storage = FlutterSecureStorage();
        const store = SecureApiKeyStore(storage);

        await store.write('  secure-key  ');
        expect(await storage.read(key: 'api_key_openai'), 'secure-key');
        expect(await store.read(), 'secure-key');

        await store.write('   ');
        expect(await storage.read(key: 'api_key_openai'), isNull);
        expect(await store.read(), isNull);
      },
    );
  });
}
