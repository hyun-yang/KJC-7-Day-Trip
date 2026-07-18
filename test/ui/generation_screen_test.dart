import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/application/generation_selection.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/domain/entities/conversation.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/providers/line_speaker.dart';
import 'package:kjc_7day_chat/domain/providers/online_text_gen_exception.dart';
import 'package:kjc_7day_chat/domain/settings/kjc_settings.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/infrastructure/settings/api_key_store.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/generation/conversation_viewer_screen.dart';
import 'package:kjc_7day_chat/ui/generation/generation_screen.dart';
import 'package:kjc_7day_chat/ui/settings/settings_screen.dart';

void main() {
  final city = citiesSeed.firstWhere((item) => item.nameEn == 'Tokyo');
  final category = kPhraseCatalog.firstWhere((item) => item.id == 'hotel');
  late GenerationSelection selection;

  setUp(() {
    selection = GenerationSelection(
      city: city,
      category: category,
      subtopic: category.subtopics.firstWhere((item) => item.id == 'check-in'),
    );
  });

  Widget app({required List<Override> overrides, Widget? home}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: home ?? GenerationScreen(selection: selection),
        ),
      );

  testWidgets('shows the selected city, category, and subtopic summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        overrides: [generationActionProvider.overrideWithValue((_) async => 1)],
      ),
    );

    expect(find.text('Tokyo · Hotel'), findsOneWidget);
    expect(
      find.text('Check-in (with or without a reservation)'),
      findsOneWidget,
    );
    expect(find.text('Generate Conversation'), findsOneWidget);
  });

  testWidgets('shows progress and ignores a second tap while generating', (
    tester,
  ) async {
    final completer = Completer<int>();
    var calls = 0;
    await tester.pumpWidget(
      app(
        overrides: [
          generationActionProvider.overrideWithValue((_) {
            calls++;
            return completer.future;
          }),
        ],
      ),
    );

    await tester.tap(find.text('Generate Conversation'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Generating conversation…'), findsOneWidget);
    await tester.tap(find.text('Generating conversation…'));
    await tester.pump();
    expect(calls, 1);

    completer.completeError(const ApiKeyMissingException());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'missing API key gives Settings guidance without opening detail',
    (tester) async {
      await tester.pumpWidget(
        app(
          overrides: [
            generationActionProvider.overrideWithValue(
              (_) async => throw const ApiKeyMissingException(),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Generate Conversation'));
      await tester.pumpAndSettle();

      expect(
        find.text('Configure your OpenAI API key in Settings, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.byType(ConversationViewerScreen), findsNothing);
    },
  );

  testWidgets('missing-key action opens Settings and retry works after save', (
    tester,
  ) async {
    final store = InMemoryApiKeyStore();
    var calls = 0;
    await tester.pumpWidget(
      app(
        overrides: [
          apiKeyStoreProvider.overrideWithValue(store),
          settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          generationActionProvider.overrideWithValue((_) async {
            calls++;
            if (await store.read() == null) {
              throw const ApiKeyMissingException();
            }
            return 42;
          }),
          conversationDetailProvider.overrideWith(
            (ref, id) async => detail(id),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Generate Conversation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('api-key-field')),
      'sk-test',
    );
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(ConversationViewerScreen), findsOneWidget);
  });

  testWidgets('online failure shows its message and Retry reruns generation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      app(
        overrides: [
          generationActionProvider.overrideWithValue((_) async {
            calls++;
            throw const OnlineTextGenException(
              provider: 'OpenAI',
              statusCode: 429,
              message: 'rate limit',
            );
          }),
        ],
      ),
    );

    await tester.tap(find.text('Generate Conversation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Rate limit exceeded — try again shortly'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets(
    'invalid and unexpected failures have retryable English messages',
    (tester) async {
      Object failure = const FormatException('bad response');
      await tester.pumpWidget(
        app(
          overrides: [
            generationActionProvider.overrideWithValue(
              (_) async => throw failure,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Generate Conversation'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The provider returned an invalid response. Please try again.',
        ),
        findsOneWidget,
      );

      failure = StateError('unexpected');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not generate the conversation. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('success loads eight lines and shows every learning field', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        overrides: [
          generationActionProvider.overrideWithValue((_) async => 42),
          conversationDetailProvider.overrideWith(
            (ref, id) async => detail(id),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Generate Conversation'));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationViewerScreen), findsOneWidget);
    for (var index = 0; index < 8; index++) {
      expect(find.text('Target $index'), findsOneWidget);
      expect(find.text('Romanization $index'), findsOneWidget);
      expect(find.text('Transliteration $index'), findsOneWidget);
      expect(find.text('Translation $index'), findsOneWidget);
    }
    expect(find.text('Traveler'), findsNWidgets(4));
    expect(find.text('Local'), findsNWidgets(4));
  });

  testWidgets('Listen passes exact line text, country, and speaker', (
    tester,
  ) async {
    final speaker = RecordingSpeaker();
    await tester.pumpWidget(
      app(
        home: const ConversationViewerScreen(conversationId: 7),
        overrides: [
          conversationDetailProvider.overrideWith(
            (ref, id) async => detail(id),
          ),
          lineSpeakerProvider.overrideWithValue(speaker),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('listen-0')));
    await tester.pump();

    expect(speaker.text, 'Target 0');
    expect(speaker.country, city.country);
    expect(speaker.speaker, 1);
    final listen = tester.getSize(find.byKey(const ValueKey('listen-0')));
    expect(listen.width, greaterThanOrEqualTo(48));
    expect(listen.height, greaterThanOrEqualTo(48));
  });

  testWidgets('viewer renders detail loading and error states', (tester) async {
    var calls = 0;
    final first = Completer<ConversationDetail>();
    await tester.pumpWidget(
      app(
        home: const ConversationViewerScreen(conversationId: 9),
        overrides: [
          conversationDetailProvider.overrideWith((ref, id) async {
            calls++;
            if (calls == 1) return first.future;
            return detail(id);
          }),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    first.completeError(StateError('missing'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load this conversation.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Target 0'), findsOneWidget);
  });

  testWidgets('speech failure is nonfatal and shows an English notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        home: const ConversationViewerScreen(conversationId: 7),
        overrides: [
          conversationDetailProvider.overrideWith(
            (ref, id) async => detail(id),
          ),
          lineSpeakerProvider.overrideWithValue(ThrowingSpeaker()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('listen-0')));
    await tester.pumpAndSettle();
    expect(find.text('Audio is unavailable right now.'), findsOneWidget);
    expect(find.byType(ConversationViewerScreen), findsOneWidget);
  });

  testWidgets(
    'Listen labels identify the exact line and viewer disposal stops speech',
    (tester) async {
      final speaker = RecordingSpeaker();
      await tester.pumpWidget(
        app(
          home: const _ViewerRouteHost(),
          overrides: [
            conversationDetailProvider.overrideWith(
              (ref, id) async => detail(id),
            ),
            lineSpeakerProvider.overrideWithValue(speaker),
          ],
        ),
      );

      await tester.tap(find.text('Open viewer'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Listen to line 1, Traveler'), findsOneWidget);
      expect(find.byTooltip('Listen to line 2, Local'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(speaker.stopCalls, 1);
    },
  );
}

ConversationDetail detail(int id) => ConversationDetail(
  conversation: Conversation(
    id: id,
    country: citiesSeed.firstWhere((item) => item.nameEn == 'Tokyo').country,
    cityId: 1,
    cityName: 'Tokyo',
    categoryId: 'hotel',
    subtopicId: 'check-in',
    subtopicLabel: 'Check-in (with or without a reservation)',
    nativeLang: NativeLanguage.english,
    model: 'gpt-test',
    createdAt: DateTime.utc(2026, 7, 18),
  ),
  lines: [
    for (var index = 0; index < 8; index++)
      ConvLine(
        lineOrder: index,
        speaker: index.isEven ? 1 : 2,
        targetText: 'Target $index',
        romanization: 'Romanization $index',
        transliteration: 'Transliteration $index',
        translation: 'Translation $index',
      ),
  ],
);

class RecordingSpeaker implements LineSpeaker {
  String? text;
  Object? country;
  int? speaker;
  int stopCalls = 0;

  @override
  Future<void> speak({
    required String text,
    required country,
    required int speaker,
  }) async {
    this.text = text;
    this.country = country;
    this.speaker = speaker;
  }

  @override
  Future<void> stop() async => stopCalls++;
}

class ThrowingSpeaker implements LineSpeaker {
  @override
  Future<void> speak({
    required String text,
    required country,
    required int speaker,
  }) {
    throw StateError('unavailable');
  }

  @override
  Future<void> stop() async {}
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> update(KjcSettings next) async => state = next;
}

class _ViewerRouteHost extends StatelessWidget {
  const _ViewerRouteHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ConversationViewerScreen(conversationId: 7),
            ),
          ),
          child: const Text('Open viewer'),
        ),
      ),
    );
  }
}
