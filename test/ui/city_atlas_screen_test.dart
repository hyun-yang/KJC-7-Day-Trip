import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/application/generation_selection.dart';
import 'package:kjc_7day_chat/domain/entities/city.dart';
import 'package:kjc_7day_chat/domain/entities/tourist_place.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/infrastructure/seed/tourist_places_seed.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/theme/atlas_theme.dart';
import 'package:kjc_7day_chat/ui/travel/city_atlas_map.dart';
import 'package:kjc_7day_chat/ui/travel/city_atlas_screen.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  final tokyo = citiesSeed.firstWhere((city) => city.nameEn == 'Tokyo');
  final tokyoPlaces = touristPlacesSeed
      .where((place) => place.cityId == tokyo.id)
      .toList(growable: false);

  Widget appFor(
    City city, {
    FutureOr<List<TouristPlace>> Function()? load,
    List<NavigatorObserver> observers = const [],
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        touristPlacesProvider.overrideWith(
          (ref, selectedCityId) =>
              load?.call() ??
              touristPlacesSeed
                  .where((place) => place.cityId == selectedCityId)
                  .toList(growable: false),
        ),
      ],
      child: MaterialApp(
        navigatorObservers: observers,
        home: CityAtlasScreen(city: city),
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('Atlas display typography uses a portable serif fallback stack', () {
    expect(AtlasTheme.display.fontFamily, 'serif');
    expect(
      AtlasTheme.display.fontFamilyFallback,
      containsAllInOrder(['Noto Serif', 'Droid Serif', 'DejaVu Serif']),
    );
  });

  testWidgets('shows exactly five selectable map pins and place rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(appFor(tokyo));
    await tester.pumpAndSettle();

    expect(find.byType(CityAtlasMap), findsOneWidget);
    expect(find.byKey(const ValueKey('atlas-place-list')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('place-pin-'),
      ),
      findsNWidgets(5),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('place-row-'),
      ),
      findsNWidgets(5),
    );
    for (final place in tokyoPlaces) {
      expect(find.text(place.nameEn), findsNWidgets(2));
      expect(find.text(place.nameLocal), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('${place.nameEn}, ${place.nameLocal}'),
        findsWidgets,
      );
      expect(
        tester.getSize(find.byKey(ValueKey('place-pin-${place.id}'))).height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('tapping a list row selects it and expands its details', (
    tester,
  ) async {
    final place = tokyoPlaces[1];
    await tester.pumpWidget(appFor(tokyo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('place-row-${place.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('place-detail-${place.id}')), findsOneWidget);
    expect(find.text(place.descriptionEn), findsOneWidget);
    expect(find.text('Recommended situations'), findsOneWidget);
    expect(find.text('All situations'), findsOneWidget);
    expect(find.byKey(const ValueKey('atlas-place-list')), findsNothing);
  });

  testWidgets('tapping a map pin selects the matching place detail', (
    tester,
  ) async {
    final place = tokyoPlaces[3];
    await tester.pumpWidget(appFor(tokyo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('place-pin-${place.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('place-detail-${place.id}')), findsOneWidget);
    expect(find.text(place.descriptionEn), findsOneWidget);
  });

  testWidgets('every map pin center is independently tappable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(appFor(tokyo));
    await tester.pumpAndSettle();

    for (final place in tokyoPlaces) {
      await tester.tap(find.byKey(ValueKey('place-pin-${place.id}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('place-detail-${place.id}')),
        findsOneWidget,
        reason: place.nameEn,
      );
    }
  });

  testWidgets(
    'compact height keeps all pins in bounds and independently tappable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(appFor(tokyo));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(CityAtlasMap)).height,
        greaterThanOrEqualTo(240),
      );
      for (final place in tokyoPlaces) {
        final pin = find.byKey(ValueKey('place-pin-${place.id}'));
        expect(pin, findsOneWidget);
        final mapRect = tester.getRect(find.byType(CityAtlasMap));
        final pinRect = tester.getRect(pin);
        expect(pinRect.left, greaterThanOrEqualTo(mapRect.left));
        expect(pinRect.top, greaterThanOrEqualTo(mapRect.top));
        expect(pinRect.right, lessThanOrEqualTo(mapRect.right));
        expect(pinRect.bottom, lessThanOrEqualTo(mapRect.bottom));

        await tester.ensureVisible(pin);
        await tester.tap(pin);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('place-detail-${place.id}')),
          findsOneWidget,
          reason: place.nameEn,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('recommended situation passes the exact place in selection', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    final place = tokyoPlaces.first;
    final scene = place.recommendedScenes.first;
    await tester.pumpWidget(appFor(tokyo, observers: [observer]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('place-row-${place.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('recommended-scene-${place.id}-0')));
    await tester.pumpAndSettle();

    final selection = observer.routes.last.settings.arguments;
    expect(selection, isA<GenerationSelection>());
    expect((selection as GenerationSelection).city, same(tokyo));
    expect(selection.place, same(place));
    expect(selection.category.id, scene.categoryId);
    expect(selection.subtopic.id, scene.subtopicId);
    expect(find.text('Create conversation'), findsOneWidget);
  });

  testWidgets('search filters places and focuses the chosen result', (
    tester,
  ) async {
    final place = tokyoPlaces.firstWhere(
      (candidate) => candidate.nameEn == 'Shibuya Crossing',
    );
    await tester.pumpWidget(appFor(tokyo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search places'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shibuya');
    await tester.pumpAndSettle();

    expect(find.text(place.nameEn), findsOneWidget);
    expect(find.text('Senso-ji Temple'), findsNothing);

    await tester.tap(find.text(place.nameEn));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('place-detail-${place.id}')), findsOneWidget);
    expect(find.text(place.descriptionEn), findsOneWidget);
  });

  testWidgets('All situations opens the place-free category flow', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    final place = tokyoPlaces.first;
    await tester.pumpWidget(appFor(tokyo, observers: [observer]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('place-row-${place.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All situations'));
    await tester.pumpAndSettle();

    expect(observer.routes.last.settings.arguments, same(tokyo));
    expect(find.text('Choose a situation'), findsOneWidget);
  });

  testWidgets('shows loading, empty, and retry states', (tester) async {
    final pending = Completer<List<TouristPlace>>();
    await tester.pumpWidget(appFor(tokyo, load: () => pending.future));
    expect(find.bySemanticsLabel('Loading places'), findsOneWidget);

    await tester.pumpWidget(appFor(tokyo, load: () => const []));
    await tester.pumpAndSettle();
    expect(find.text('No places available'), findsOneWidget);

    await tester.pumpWidget(
      appFor(
        tokyo,
        load: () => Future<List<TouristPlace>>.error(StateError('offline')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load places'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('connection'), findsNothing);
  });

  testWidgets('retry invalidates the provider and recovers its places', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      appFor(
        tokyo,
        load: () {
          attempts++;
          if (attempts == 1) {
            return Future<List<TouristPlace>>.error(StateError('broken seed'));
          }
          return tokyoPlaces;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load places'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const ValueKey('atlas-place-list')), findsOneWidget);
    expect(find.text('Ueno Park'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('place-pin-'),
      ),
      findsNWidgets(5),
    );
  });
}
