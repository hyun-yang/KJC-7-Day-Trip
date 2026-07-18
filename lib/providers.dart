import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'application/generation_orchestrator.dart';
import 'application/generation_selection.dart';
import 'domain/entities/city.dart';
import 'domain/entities/conversation.dart';
import 'domain/entities/country.dart';
import 'domain/providers/line_speaker.dart';
import 'domain/providers/online_text_gen_exception.dart';
import 'domain/providers/text_gen_provider.dart';
import 'domain/settings/kjc_settings.dart';
import 'infrastructure/db/city_repository.dart';
import 'infrastructure/db/conversation_repository.dart';
import 'infrastructure/online/openai_text_gen_provider.dart';
import 'infrastructure/settings/api_key_store.dart';
import 'infrastructure/settings/settings_repository.dart';
import 'infrastructure/tts/system_line_speaker.dart';

final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final settingsDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('settingsDirProvider must be overridden'),
);

final cityRepositoryProvider = Provider(
  (ref) => CityRepository(ref.watch(databaseProvider)),
);

final conversationRepositoryProvider = Provider(
  (ref) => ConversationRepository(ref.watch(databaseProvider)),
);

/// Saved conversations, ordered newest first by the repository.
final conversationsProvider = FutureProvider<List<Conversation>>(
  (ref) => ref.watch(conversationRepositoryProvider).listAll(),
);

final citiesProvider = FutureProvider.family<List<City>, Country>(
  (ref, country) => ref.watch(cityRepositoryProvider).listByCountry(country),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(settingsDirProvider)),
);

final initialSettingsProvider = Provider<KjcSettings>(
  (ref) => const KjcSettings(),
);

final settingsProvider = NotifierProvider<SettingsNotifier, KjcSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<KjcSettings> {
  @override
  KjcSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(KjcSettings next) async {
    final previous = state;
    state = next;
    try {
      await ref.read(settingsRepositoryProvider).save(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final apiKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => const SecureApiKeyStore(),
);

final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(
  ApiKeyNotifier.new,
);

class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.read(apiKeyStoreProvider).read();

  Future<void> write(String key) async {
    final previous = state;
    state = const AsyncLoading();
    try {
      await ref.read(apiKeyStoreProvider).write(key);
      state = AsyncData(await ref.read(apiKeyStoreProvider).read());
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> clear() => write('');
}

final textGenProvider = FutureProvider<TextGenProvider>((ref) async {
  final settings = ref.watch(settingsProvider);
  final key = await ref.watch(apiKeyProvider.future);
  if (key == null || key.isEmpty) {
    throw const ApiKeyMissingException();
  }
  return OpenAiTextGenProvider(apiKey: key, model: settings.openaiModel);
});

final orchestratorProvider = FutureProvider<GenerationOrchestrator>((
  ref,
) async {
  return GenerationOrchestrator(
    textGen: await ref.watch(textGenProvider.future),
    repo: ref.watch(conversationRepositoryProvider),
    model: ref.watch(settingsProvider).openaiModel,
  );
});

final lineSpeakerProvider = Provider<LineSpeaker>(
  (ref) => Platform.isAndroid ? SystemLineSpeaker() : const SilentLineSpeaker(),
);

typedef GenerationAction = Future<int> Function(GenerationSelection selection);
typedef DeleteConversationAction = Future<void> Function(int id);

/// Testable repository boundary used by the stable delete action.
final deleteConversationRepositoryActionProvider =
    Provider<DeleteConversationAction>((ref) {
      return (id) => ref.read(conversationRepositoryProvider).delete(id);
    });

/// Deletes a conversation and refreshes every Saved Conversations consumer.
final deleteConversationProvider = Provider<DeleteConversationAction>((ref) {
  final deleteFromRepository = ref.watch(
    deleteConversationRepositoryActionProvider,
  );
  return (id) async {
    await deleteFromRepository(id);
    ref.invalidate(conversationsProvider);
  };
});

/// Testable UI boundary for generating and saving the current selection.
final generationActionProvider = Provider<GenerationAction>((ref) {
  return (selection) async {
    final orchestrator = await ref.read(orchestratorProvider.future);
    final id = await orchestrator.generateAndSave(
      country: selection.city.country,
      city: selection.city,
      category: selection.category,
      subtopic: selection.subtopic,
      nativeLanguage: ref.read(settingsProvider).nativeLanguage,
    );
    ref.invalidate(conversationsProvider);
    return id;
  };
});

/// Testable detail-loading boundary used by generation and saved conversations.
final conversationDetailProvider =
    FutureProvider.family<ConversationDetail, int>(
      (ref, id) => ref.watch(conversationRepositoryProvider).load(id),
    );
