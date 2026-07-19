import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/catalog/practice_catalog.dart';
import 'package:kjc_7day_chat/domain/entities/city.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/generation/generation_screen.dart';
import 'package:kjc_7day_chat/ui/practice/practice_screen.dart';

void main() {
  List<City> countryCities(Country country) => citiesSeed
      .where((city) => city.country == country)
      .toList(growable: false);

  Widget app(Future<List<City>> Function(Country country) loadCities) =>
      ProviderScope(
        overrides: [
          citiesProvider.overrideWith((ref, country) => loadCities(country)),
        ],
        child: const MaterialApp(home: PracticeScreen()),
      );

  Future<void> openFirstKoreaScene(WidgetTester tester) async {
    final group = practiceGroupsFor(Country.korea).first;
    await tester.tap(find.byKey(ValueKey('practice-group-${group.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('practice-scene-${group.id}-0')));
    await tester.pump();
  }

  testWidgets('shows Atlas heading, three country segments, and count 15', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app((country) async => countryCities(country)));

    expect(find.text('Practice'), findsOneWidget);
    expect(
      find.text('Choose a situation and practise useful phrases.'),
      findsOneWidget,
    );
    for (final country in Country.values) {
      expect(
        find.byKey(ValueKey('practice-country-${country.dbValue}')),
        findsOneWidget,
      );
    }
    expect(find.text('All situations'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-group-cafe-dining')),
      findsOneWidget,
    );

    final segment = tester.getSize(
      find.byKey(const ValueKey('practice-country-KR')),
    );
    expect(segment.height, greaterThanOrEqualTo(44));
  });

  testWidgets('switches country-specific group content', (tester) async {
    await tester.pumpWidget(app((country) async => countryCities(country)));

    expect(find.text('Cafés & casual dining'), findsOneWidget);
    expect(find.text('Shrines & sightseeing'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('practice-country-JP')));
    await tester.pumpAndSettle();

    expect(find.text('Cafés & casual dining'), findsNothing);
    expect(find.text('Shrines & sightseeing'), findsOneWidget);
  });

  testWidgets('expands one open-list group to its three real scenes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app((country) async => countryCities(country)));
    final group = practiceGroupsFor(Country.korea).first;

    final groupFinder = find.byKey(ValueKey('practice-group-${group.id}'));
    expect(tester.getSize(groupFinder).height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel(RegExp(group.labelEn)), findsOneWidget);

    await tester.tap(groupFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('practice-group-panel-${group.id}')),
      findsOneWidget,
    );
    for (var index = 0; index < group.scenes.length; index++) {
      expect(
        find.byKey(ValueKey('practice-scene-${group.id}-$index')),
        findsOneWidget,
      );
      expect(find.text(group.scenes[index].labelEn), findsOneWidget);
      final sceneFinder = find.byKey(
        ValueKey('practice-scene-${group.id}-$index'),
      );
      expect(tester.getSize(sceneFinder).height, greaterThanOrEqualTo(44));
      expect(
        find.bySemanticsLabel(group.scenes[index].labelEn),
        findsOneWidget,
      );
    }
    semantics.dispose();
  });

  testWidgets(
    'scene opens exact five country cities then place-free generation',
    (tester) async {
      await tester.pumpWidget(app((country) async => countryCities(country)));
      final group = practiceGroupsFor(Country.korea).first;
      final scene = group.scenes.first;

      await openFirstKoreaScene(tester);
      await tester.pumpAndSettle();

      expect(find.text('Choose a city'), findsOneWidget);
      final koreaCities = countryCities(Country.korea);
      expect(koreaCities, hasLength(5));
      for (final city in koreaCities) {
        final cityFinder = find.byKey(ValueKey('practice-city-${city.id}'));
        expect(cityFinder, findsOneWidget);
        expect(tester.getSize(cityFinder).height, greaterThanOrEqualTo(44));
        expect(
          find.bySemanticsLabel('Choose ${city.nameEn}, ${city.nameLocal}'),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('practice-city-11')), findsNothing);

      await tester.tap(
        find.byKey(ValueKey('practice-city-${koreaCities.first.id}')),
      );
      await tester.pumpAndSettle();

      final generation = tester.widget<GenerationScreen>(
        find.byType(GenerationScreen),
      );
      expect(generation.selection.city, same(koreaCities.first));
      expect(generation.selection.category.id, scene.categoryId);
      expect(generation.selection.subtopic.id, scene.subtopicId);
      expect(generation.selection.place, isNull);
    },
  );

  testWidgets('city chooser shows loading until cities arrive', (tester) async {
    final completer = Completer<List<City>>();
    await tester.pumpWidget(app((country) => completer.future));

    await openFirstKoreaScene(tester);
    expect(find.bySemanticsLabel('Loading cities'), findsOneWidget);

    completer.complete(countryCities(Country.korea));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('practice-city-1')), findsOneWidget);
  });

  testWidgets('city chooser reports error and retries', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      app((country) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return countryCities(country);
      }),
    );

    await openFirstKoreaScene(tester);
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load cities'), findsOneWidget);

    final retryFinder = find.ancestor(
      of: find.text('Try again'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(retryFinder, findsOneWidget);
    expect(tester.getSize(retryFinder).height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);

    await tester.tap(retryFinder);
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const ValueKey('practice-city-1')), findsOneWidget);
  });

  testWidgets('city chooser has a clear empty state', (tester) async {
    await tester.pumpWidget(app((country) async => const <City>[]));

    await openFirstKoreaScene(tester);
    await tester.pumpAndSettle();

    expect(find.text('No cities available'), findsOneWidget);
    expect(
      find.text('Choose a different country and try again.'),
      findsOneWidget,
    );
  });
}
