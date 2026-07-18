import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/application/generation_selection.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/domain/providers/online_text_gen_exception.dart';
import 'package:kjc_7day_chat/domain/providers/text_gen_provider.dart';
import 'package:kjc_7day_chat/infrastructure/online/openai_text_gen_provider.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/infrastructure/settings/api_key_store.dart';
import 'package:kjc_7day_chat/providers.dart';

import 'helpers/test_db.dart';

void main() {
  test(
    'saving an API key rebuilds a previously failed text provider',
    () async {
      final store = InMemoryApiKeyStore();
      final container = ProviderContainer(
        overrides: [apiKeyStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(textGenProvider.future),
        throwsA(isA<ApiKeyMissingException>()),
      );

      await container.read(apiKeyProvider.notifier).write('  sk-test  ');

      expect(
        await container.read(textGenProvider.future),
        isA<OpenAiTextGenProvider>(),
      );
      expect(await store.read(), 'sk-test');
    },
  );

  test('clearing an API key updates notifier state', () async {
    final store = InMemoryApiKeyStore();
    await store.write('sk-test');
    final container = ProviderContainer(
      overrides: [apiKeyStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(await container.read(apiKeyProvider.future), 'sk-test');
    await container.read(apiKeyProvider.notifier).clear();

    expect(container.read(apiKeyProvider).value, isNull);
    expect(await store.read(), isNull);
  });

  test('failed API key writes restore the previous usable key', () async {
    final store = _FailingApiKeyStore('sk-working');
    final container = ProviderContainer(
      overrides: [apiKeyStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(await container.read(apiKeyProvider.future), 'sk-working');
    expect(
      await container.read(textGenProvider.future),
      isA<OpenAiTextGenProvider>(),
    );

    store.failWrites = true;
    await expectLater(
      container.read(apiKeyProvider.notifier).write('sk-broken'),
      throwsStateError,
    );
    expect(container.read(apiKeyProvider).value, 'sk-working');
    expect(container.read(apiKeyProvider).hasError, isFalse);
    expect(
      await container.read(textGenProvider.future),
      isA<OpenAiTextGenProvider>(),
    );

    await expectLater(
      container.read(apiKeyProvider.notifier).clear(),
      throwsStateError,
    );
    expect(container.read(apiKeyProvider).value, 'sk-working');
    expect(container.read(apiKeyProvider).hasError, isFalse);
    expect(await store.read(), 'sk-working');
  });

  test('successful generation refreshes the saved conversation list', () async {
    final database = await openTestDb();
    addTearDown(database.close);
    final city = citiesSeed.firstWhere((item) => item.nameEn == 'Tokyo');
    final category = kPhraseCatalog.first;
    final selection = GenerationSelection(
      city: city,
      category: category,
      subtopic: category.subtopics.first,
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        textGenProvider.overrideWith((ref) async => const _ValidTextGen()),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(conversationsProvider.future), isEmpty);
    await container.read(generationActionProvider)(selection);

    expect(await container.read(conversationsProvider.future), hasLength(1));
  });
}

class _ValidTextGen implements TextGenProvider {
  const _ValidTextGen();

  @override
  String get name => 'Test';

  @override
  Future<String> generate(String prompt) async => jsonEncode({
    'lines': [
      for (var index = 0; index < 8; index++)
        {
          'speaker': index.isEven ? 1 : 2,
          'text': 'こんにちは',
          'romanization': 'konnichiwa',
          'transliteration': 'hello',
          'translation': 'hello',
        },
    ],
  });
}

class _FailingApiKeyStore implements ApiKeyStore {
  _FailingApiKeyStore(this.value);

  String? value;
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async {
    if (failWrites) throw StateError('secure storage unavailable');
    value = key.trim().isEmpty ? null : key.trim();
  }
}
