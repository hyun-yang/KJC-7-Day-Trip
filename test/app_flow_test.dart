import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/app.dart';
import 'package:kjc_7day_chat/application/generation_selection.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/domain/entities/conversation.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/infrastructure/seed/tourist_places_seed.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/generation/conversation_viewer_screen.dart';

void main() {
  testWidgets(
    'creates, saves, lists, and reopens a conversation through KjcApp',
    (tester) async {
      final tokyo = citiesSeed.firstWhere((city) => city.nameEn == 'Tokyo');
      final place = touristPlacesSeed.firstWhere(
        (candidate) => candidate.cityId == tokyo.id,
      );
      final scene = place.recommendedScenes.first;
      final sightseeing = kPhraseCatalog.firstWhere(
        (category) => category.id == scene.categoryId,
      );
      final generation = Completer<int>();
      final saved = <Conversation>[];
      final requestedDetailIds = <int>[];
      GenerationSelection? receivedSelection;
      final conversation = Conversation(
        id: 42,
        placeId: place.id,
        placeName: place.nameEn,
        country: Country.japan,
        cityId: tokyo.id,
        cityName: tokyo.nameEn,
        categoryId: sightseeing.id,
        subtopicId: scene.subtopicId,
        subtopicLabel: scene.labelEn,
        nativeLang: NativeLanguage.english,
        model: 'gpt-5.4-mini',
        createdAt: DateTime.utc(2026, 7, 18),
      );
      final savedDetail = ConversationDetail(
        conversation: conversation,
        lines: [
          for (var index = 0; index < 8; index++)
            ConvLine(
              lineOrder: index,
              speaker: index.isEven ? 1 : 2,
              targetText: 'こんにちは $index',
              romanization: 'konnichiwa $index',
              transliteration: 'Native script $index',
              translation: 'Translation $index',
            ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            citiesProvider.overrideWith(
              (ref, country) async => citiesSeed
                  .where((city) => city.country == country)
                  .toList(growable: false),
            ),
            conversationsProvider.overrideWith(
              (ref) async => List<Conversation>.unmodifiable(saved),
            ),
            generationActionProvider.overrideWith((ref) {
              return (selection) async {
                receivedSelection = selection;
                final id = await generation.future;
                saved.add(conversation);
                ref.invalidate(conversationsProvider);
                return id;
              };
            }),
            conversationDetailProvider.overrideWith((ref, id) async {
              requestedDetailIds.add(id);
              if (id != 42) {
                throw StateError('Unexpected conversation ID: $id');
              }
              return savedDetail;
            }),
          ],
          child: const KjcApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('country-card-JP')));
      await tester.pumpAndSettle();
      expect(find.text('Explore Japan'), findsOneWidget);

      final tokyoChip = find.byKey(ValueKey('city-chip-${tokyo.id}'));
      await tester.ensureVisible(tokyoChip);
      await tester.tap(tokyoChip);
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a place to practise for your trip.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ValueKey('place-row-${place.id}')));
      await tester.pumpAndSettle();
      final recommendedScene = find.byKey(
        ValueKey('recommended-scene-${place.id}-0'),
      );
      await tester.ensureVisible(recommendedScene);
      await tester.pumpAndSettle();
      await tester.tap(recommendedScene);
      await tester.pumpAndSettle();
      expect(find.text('Generate Conversation'), findsOneWidget);

      await tester.tap(find.text('Generate Conversation'));
      await tester.pump();
      expect(find.text('Generating conversation…'), findsOneWidget);
      expect(receivedSelection?.city, same(tokyo));
      expect(receivedSelection?.category, same(sightseeing));
      expect(receivedSelection?.subtopic.id, scene.subtopicId);
      expect(receivedSelection?.place, same(place));

      generation.complete(42);
      await tester.pumpAndSettle();

      expect(saved.single.placeId, place.id);
      expect(saved.single.placeName, place.nameEn);

      expect(find.byType(ConversationViewerScreen), findsOneWidget);
      expect(
        tester
            .widget<ConversationViewerScreen>(
              find.byType(ConversationViewerScreen),
            )
            .conversationId,
        42,
      );
      expect(requestedDetailIds, [42]);
      for (var index = 0; index < 8; index++) {
        expect(find.text('こんにちは $index'), findsOneWidget);
        expect(find.text('konnichiwa $index'), findsOneWidget);
        expect(find.text('Native script $index'), findsOneWidget);
        expect(find.text('Translation $index'), findsOneWidget);
      }

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();

      expect(find.text('Saved Conversations'), findsOneWidget);
      expect(find.text(scene.labelEn), findsOneWidget);
      expect(find.text(place.nameEn), findsOneWidget);
      expect(find.text('🇯🇵 Japan'), findsOneWidget);
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('2026-07-18'), findsOneWidget);

      await tester.tap(find.text(scene.labelEn));
      await tester.pumpAndSettle();

      expect(find.byType(ConversationViewerScreen), findsOneWidget);
      expect(
        tester
            .widget<ConversationViewerScreen>(
              find.byType(ConversationViewerScreen),
            )
            .conversationId,
        42,
      );
      // The family provider retains the already validated detail for this ID.
      expect(requestedDetailIds, [42]);
      expect(find.text('こんにちは 0'), findsOneWidget);
      expect(find.text('Translation 7'), findsOneWidget);
    },
  );
}
