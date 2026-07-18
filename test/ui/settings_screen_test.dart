import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/settings/kjc_settings.dart';
import 'package:kjc_7day_chat/infrastructure/settings/api_key_store.dart';
import 'package:kjc_7day_chat/infrastructure/settings/settings_repository.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/settings/settings_screen.dart';

void main() {
  late InMemoryApiKeyStore keyStore;
  late _RecordingSettingsRepository repository;

  setUp(() {
    keyStore = InMemoryApiKeyStore();
    repository = _RecordingSettingsRepository();
  });

  Widget app({
    KjcSettings initial = const KjcSettings(),
    ApiKeyStore? apiKeyStore,
    Widget home = const SettingsScreen(),
  }) => ProviderScope(
    overrides: [
      initialSettingsProvider.overrideWithValue(initial),
      settingsRepositoryProvider.overrideWithValue(repository),
      apiKeyStoreProvider.overrideWithValue(apiKeyStore ?? keyStore),
    ],
    child: MaterialApp(home: home),
  );

  testWidgets('shows all languages and exact supported models in English', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('language-field')));
    await tester.pumpAndSettle();
    for (final language in NativeLanguage.values) {
      expect(find.text(language.promptName), findsWidgets);
    }
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('model-field')));
    await tester.pumpAndSettle();
    for (final model in kOpenAiModels) {
      expect(find.text(model), findsWidgets);
    }
  });

  testWidgets('never prefills a stored key and obscures replacement input', (
    tester,
  ) async {
    await keyStore.write('sk-existing-secret');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('API key configured'), findsOneWidget);
    expect(find.text('sk-existing-secret'), findsNothing);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('api-key-field')),
    );
    expect(field.obscureText, isTrue);
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('saves language, model, and a trimmed replacement key', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('language-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korean').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('model-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-5.4').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('api-key-field')),
      '  sk-replacement  ',
    );
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(repository.saved.single.nativeLanguage, NativeLanguage.korean);
    expect(repository.saved.single.openaiModel, 'gpt-5.4');
    expect(await keyStore.read(), 'sk-replacement');
    expect(find.text('Settings saved.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('api-key-field')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('clears a configured API key securely', (tester) async {
    await keyStore.write('sk-existing');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear API Key'));
    await tester.pumpAndSettle();

    expect(await keyStore.read(), isNull);
    expect(find.text('No API key configured'), findsOneWidget);
  });

  testWidgets('shows save errors and restores persisted settings state', (
    tester,
  ) async {
    repository.failure = StateError('disk unavailable');
    await tester.pumpWidget(
      app(initial: const KjcSettings(nativeLanguage: NativeLanguage.english)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('language-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save settings. Please try again.'),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
  });

  testWidgets('reports partial success and preserves the prior key', (
    tester,
  ) async {
    final store = _ControlledApiKeyStore(value: 'sk-working')
      ..failWrites = true;
    await tester.pumpWidget(app(apiKeyStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('language-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('German').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('api-key-field')),
      'sk-replacement',
    );
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(repository.saved.single.nativeLanguage, NativeLanguage.german);
    expect(await store.read(), 'sk-working');
    expect(
      find.text(
        'Preferences saved, but the API key could not be updated. '
        'Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('API key configured'), findsOneWidget);
  });

  testWidgets('disables controls and ignores duplicate saves while pending', (
    tester,
  ) async {
    repository.wait = Completer<void>();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Settings'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(repository.saved, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Saving settings'), findsOneWidget);
    repository.wait!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('pending save can finish after the Settings route is closed', (
    tester,
  ) async {
    repository.wait = Completer<void>();
    await tester.pumpWidget(app(home: const _SettingsRouteHost()));
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('api-key-field')),
      'sk-new',
    );
    await tester.tap(find.text('Save Settings'));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    repository.wait!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await keyStore.read(), 'sk-new');
  });

  testWidgets('pending clear can finish after the Settings route is closed', (
    tester,
  ) async {
    final store = _ControlledApiKeyStore(value: 'sk-working');
    await tester.pumpWidget(
      app(apiKeyStore: store, home: const _SettingsRouteHost()),
    );
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    store.pendingWrite = Completer<void>();
    await tester.tap(find.text('Clear API Key'));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    store.pendingWrite!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await store.read(), isNull);
  });
}

class _RecordingSettingsRepository extends SettingsRepository {
  _RecordingSettingsRepository() : super(Directory('/unused'));

  final List<KjcSettings> saved = [];
  Object? failure;
  Completer<void>? wait;

  @override
  Future<void> save(KjcSettings settings) async {
    if (failure case final error?) throw error;
    saved.add(settings);
    await wait?.future;
  }
}

class _ControlledApiKeyStore implements ApiKeyStore {
  _ControlledApiKeyStore({this.value});

  String? value;
  bool failWrites = false;
  Completer<void>? pendingWrite;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async {
    if (failWrites) throw StateError('secure storage unavailable');
    await pendingWrite?.future;
    value = key.trim().isEmpty ? null : key.trim();
  }
}

class _SettingsRouteHost extends StatelessWidget {
  const _SettingsRouteHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        child: const Text('Open Settings'),
      ),
    ),
  );
}
