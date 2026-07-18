import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/conversation.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/providers/line_speaker.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/generation/conversation_viewer_screen.dart';
import 'package:kjc_7day_chat/ui/library/library_screen.dart';

void main() {
  Widget app(List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: LibraryScreen()),
  );

  testWidgets('shows a clear empty state when nothing has been saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([conversationsProvider.overrideWith((ref) async => [])]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Conversations'), findsOneWidget);
    expect(find.text('No saved conversations yet.'), findsOneWidget);
  });

  testWidgets('announces the loading state while saved data is pending', (
    tester,
  ) async {
    final pending = Completer<List<Conversation>>();
    await tester.pumpWidget(
      app([conversationsProvider.overrideWith((ref) => pending.future)]),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Loading saved conversations'),
      findsOneWidget,
    );
    pending.complete([]);
  });

  testWidgets('renders saved metadata in provider order', (tester) async {
    final newest = conversation(
      id: 2,
      country: Country.japan,
      city: 'Tokyo',
      situation: 'Checking in',
      createdAt: DateTime.utc(2026, 7, 18),
    );
    final older = conversation(
      id: 1,
      country: Country.korea,
      city: 'Seoul',
      situation: 'Ordering food',
      createdAt: DateTime.utc(2026, 7, 17),
    );

    await tester.pumpWidget(
      app([
        conversationsProvider.overrideWith((ref) async => [newest, older]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('🇯🇵 Japan'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Checking in'), findsOneWidget);
    expect(find.text('2026-07-18'), findsOneWidget);
    expect(find.text('🇰🇷 Korea'), findsOneWidget);
    expect(find.text('Seoul'), findsOneWidget);
    expect(find.text('Ordering food'), findsOneWidget);
    expect(find.text('2026-07-17'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Checking in')).dy,
      lessThan(tester.getTopLeft(find.text('Ordering food')).dy),
    );
  });

  testWidgets('tapping a card opens the reusable viewer with its id', (
    tester,
  ) async {
    final saved = conversation(
      id: 42,
      country: Country.china,
      city: 'Beijing',
      situation: 'Buying a ticket',
      createdAt: DateTime.utc(2026, 7, 18),
    );
    int? loadedId;
    await tester.pumpWidget(
      app([
        conversationsProvider.overrideWith((ref) async => [saved]),
        conversationDetailProvider.overrideWith((ref, id) async {
          loadedId = id;
          return detail(saved);
        }),
        lineSpeakerProvider.overrideWithValue(const SilentTestSpeaker()),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buying a ticket'));
    await tester.pumpAndSettle();

    expect(loadedId, 42);
    expect(find.byType(ConversationViewerScreen), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
  });

  testWidgets('list error offers Retry and reloads', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      app([
        conversationsProvider.overrideWith((ref) async {
          loads++;
          if (loads == 1) throw StateError('offline');
          return [];
        }),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load saved conversations.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('No saved conversations yet.'), findsOneWidget);
  });

  testWidgets('delete requires confirmation, cancel keeps, confirm refreshes', (
    tester,
  ) async {
    final saved = conversation(
      id: 7,
      country: Country.korea,
      city: 'Seoul',
      situation: 'Ordering food',
      createdAt: DateTime.utc(2026, 7, 18),
    );
    final items = <Conversation>[saved];
    final deleted = <int>[];
    var loads = 0;
    await tester.pumpWidget(
      app([
        conversationsProvider.overrideWith((ref) async {
          loads++;
          return List.of(items);
        }),
        deleteConversationRepositoryActionProvider.overrideWithValue((
          id,
        ) async {
          deleted.add(id);
          items.removeWhere((item) => item.id == id);
        }),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-conversation-7')));
    await tester.pumpAndSettle();
    expect(find.text('Delete conversation?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('Ordering food'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-conversation-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, [7]);
    expect(loads, 2);
    expect(find.text('No saved conversations yet.'), findsOneWidget);
  });

  testWidgets('failed delete keeps the item and Retry succeeds exactly once', (
    tester,
  ) async {
    final saved = conversation(
      id: 8,
      country: Country.japan,
      city: 'Osaka',
      situation: 'Asking directions',
      createdAt: DateTime.utc(2026, 7, 18),
    );
    final items = <Conversation>[saved];
    var deleteCalls = 0;
    var loads = 0;
    await tester.pumpWidget(
      app([
        conversationsProvider.overrideWith((ref) async {
          loads++;
          return List.of(items);
        }),
        deleteConversationRepositoryActionProvider.overrideWithValue((
          id,
        ) async {
          deleteCalls++;
          if (deleteCalls == 1) throw StateError('busy');
          items.removeWhere((item) => item.id == id);
        }),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-conversation-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    expect(loads, 1);
    expect(find.text('Asking directions'), findsOneWidget);
    expect(find.text('Could not delete this conversation.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 2);
    expect(loads, 2);
    expect(find.text('No saved conversations yet.'), findsOneWidget);
  });

  testWidgets('pending delete disables its control and survives route pop', (
    tester,
  ) async {
    final saved = conversation(
      id: 9,
      country: Country.china,
      city: 'Shanghai',
      situation: 'Taking a taxi',
      createdAt: DateTime.utc(2026, 7, 18),
    );
    final pendingDelete = Completer<void>();
    final items = <Conversation>[saved];
    var deleteCalls = 0;
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        conversationsProvider.overrideWith((ref) async {
          loads++;
          return List.of(items);
        }),
        deleteConversationRepositoryActionProvider.overrideWithValue((
          id,
        ) async {
          deleteCalls++;
          await pendingDelete.future;
          items.removeWhere((item) => item.id == id);
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _LibraryRouteHost()),
      ),
    );
    await tester.tap(find.text('Open saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-conversation-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();

    final deleteButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('delete-conversation-9')),
    );
    expect(deleteButton.onPressed, isNull);
    expect(deleteCalls, 1);

    await tester.tap(find.text('Taking a taxi'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ConversationViewerScreen), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    pendingDelete.complete();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(await container.read(conversationsProvider.future), isEmpty);
    expect(loads, 2);
  });
}

Conversation conversation({
  required int id,
  required Country country,
  required String city,
  required String situation,
  required DateTime createdAt,
}) => Conversation(
  id: id,
  country: country,
  cityId: id,
  cityName: city,
  categoryId: 'hotel',
  subtopicId: 'check-in',
  subtopicLabel: situation,
  nativeLang: NativeLanguage.english,
  model: 'gpt-test',
  createdAt: createdAt,
);

ConversationDetail detail(Conversation value) => ConversationDetail(
  conversation: value,
  lines: const [
    ConvLine(
      lineOrder: 0,
      speaker: 1,
      targetText: 'Target',
      romanization: 'Romanization',
      transliteration: 'Transliteration',
      translation: 'Translation',
    ),
  ],
);

class SilentTestSpeaker implements LineSpeaker {
  const SilentTestSpeaker();

  @override
  Future<void> speak({
    required String text,
    required Country country,
    required int speaker,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _LibraryRouteHost extends StatelessWidget {
  const _LibraryRouteHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LibraryScreen())),
        child: const Text('Open saved'),
      ),
    ),
  );
}
