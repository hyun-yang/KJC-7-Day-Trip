import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kjc_7day_chat/app.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/providers/line_speaker.dart';
import 'package:kjc_7day_chat/domain/providers/online_text_gen_exception.dart';
import 'package:kjc_7day_chat/domain/settings/kjc_settings.dart';
import 'package:kjc_7day_chat/infrastructure/tts/system_line_speaker.dart';
import 'package:kjc_7day_chat/infrastructure/settings/api_key_store.dart';
import 'package:kjc_7day_chat/infrastructure/settings/settings_repository.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/settings/settings_screen.dart';

void main() {
  testWidgets('switches between Travel and Saved tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith((ref) async => const []),
        ],
        child: const KjcApp(),
      ),
    );

    expect(find.text('KJC 7-Day Trip'), findsOneWidget);
    expect(find.text('Where are you going?'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Conversations'), findsOneWidget);
    expect(find.text('No saved conversations yet.'), findsOneWidget);

    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();

    expect(find.text('KJC 7-Day Trip'), findsOneWidget);
  });

  testWidgets('opens Settings from both Travel and Saved app bars', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith((ref) async => const []),
          apiKeyStoreProvider.overrideWithValue(InMemoryApiKeyStore()),
        ],
        child: const KjcApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  group('SystemLineSpeaker', () {
    const channel = MethodChannel('flutter_tts');
    final calls = <MethodCall>[];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return 1;
          });
    });

    tearDown(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'stops then configures country and traveler pitch before speaking',
      () async {
        final speaker = SystemLineSpeaker(tts: FlutterTts());

        await speaker.speak(text: '안녕하세요', country: Country.korea, speaker: 1);

        expect(calls.map((call) => (call.method, call.arguments)), const [
          ('stop', null),
          ('setLanguage', 'ko-KR'),
          ('setPitch', 1.1),
          ('speak', '안녕하세요'),
        ]);
      },
    );

    test('uses local and default pitches and delegates stop', () async {
      final speaker = SystemLineSpeaker(tts: FlutterTts());

      await speaker.speak(text: 'こんにちは', country: Country.japan, speaker: 2);
      expect((calls[2].method, calls[2].arguments), ('setPitch', 0.85));

      calls.clear();
      await speaker.speak(text: '你好', country: Country.china, speaker: 9);
      expect((calls[2].method, calls[2].arguments), ('setPitch', 1.0));

      calls.clear();
      await speaker.stop();
      expect(calls.map((call) => call.method), ['stop']);
    });
  });

  test('SilentLineSpeaker completes without platform calls', () async {
    const speaker = SilentLineSpeaker();
    await speaker.speak(text: 'hello', country: Country.korea, speaker: 1);
    await speaker.stop();
  });

  group('providers', () {
    test('database and settings directory require startup overrides', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() => container.read(databaseProvider), throwsUnimplementedError);
      expect(
        () => container.read(settingsDirProvider),
        throwsUnimplementedError,
      );
    });

    test('settings start from override and update persists', () async {
      final directory = Directory.systemTemp.createTempSync('kjc_settings_');
      addTearDown(() => directory.deleteSync(recursive: true));
      const initial = KjcSettings(nativeLanguage: NativeLanguage.korean);
      const next = KjcSettings(
        nativeLanguage: NativeLanguage.japanese,
        openaiModel: 'gpt-5.4',
      );
      final container = ProviderContainer(
        overrides: [
          settingsDirProvider.overrideWithValue(directory),
          initialSettingsProvider.overrideWithValue(initial),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(settingsProvider), same(initial));

      await container.read(settingsProvider.notifier).update(next);

      expect(container.read(settingsProvider), same(next));
      expect(await SettingsRepository(directory).load(), isA<KjcSettings>());
      final persisted = await SettingsRepository(directory).load();
      expect(persisted.nativeLanguage, NativeLanguage.japanese);
      expect(persisted.openaiModel, 'gpt-5.4');
    });

    test('text generation provider reports a missing API key', () async {
      final container = ProviderContainer(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(InMemoryApiKeyStore()),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(textGenProvider.future),
        throwsA(isA<ApiKeyMissingException>()),
      );
    });

    test('Linux uses the silent line speaker', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(lineSpeakerProvider), isA<SilentLineSpeaker>());
    });
  });
}
