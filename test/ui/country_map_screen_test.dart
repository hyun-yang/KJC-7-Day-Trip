import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/city.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/providers.dart';
import 'package:kjc_7day_chat/ui/map/country_map_painter.dart';
import 'package:kjc_7day_chat/ui/map/country_map_screen.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  Widget appFor(
    Country country, {
    List<NavigatorObserver> observers = const [],
  }) {
    return ProviderScope(
      overrides: [
        citiesProvider.overrideWith(
          (ref, selected) async => citiesSeed
              .where((city) => city.country == selected)
              .toList(growable: false),
        ),
      ],
      child: MaterialApp(
        navigatorObservers: observers,
        home: CountryMapScreen(country: country),
      ),
    );
  }

  testWidgets('Japan map shows exactly five selectable cities', (tester) async {
    await tester.pumpWidget(appFor(Country.japan));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('city-marker-'),
      ),
      findsNWidgets(5),
    );
    for (final name in ['Tokyo', 'Osaka', 'Kyoto', 'Fukuoka', 'Sapporo']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('selecting Tokyo passes the full City to the next route', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    final tokyo = citiesSeed.firstWhere((city) => city.nameEn == 'Tokyo');
    await tester.pumpWidget(appFor(Country.japan, observers: [observer]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('city-chip-${tokyo.id}')));
    await tester.pumpAndSettle();

    expect(observer.routes, hasLength(2));
    expect(observer.routes.last.settings.arguments, same(tokyo));
    expect(find.text('Tokyo'), findsOneWidget);
    expect(
      find.text('Choose a place to practise for your trip.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an accessible loading state while cities load', (
    tester,
  ) async {
    final pending = Completer<List<City>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          citiesProvider.overrideWith((ref, country) => pending.future),
        ],
        child: const MaterialApp(
          home: CountryMapScreen(country: Country.korea),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Loading cities'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a retry action when cities fail to load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          citiesProvider.overrideWith(
            (ref, country) => Future<List<City>>.error(StateError('offline')),
          ),
        ],
        child: const MaterialApp(
          home: CountryMapScreen(country: Country.china),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load cities'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets(
    'all country markers have 48 pixel non-overlapping targets inside the map',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final country in Country.values) {
        await tester.pumpWidget(appFor(country));
        await tester.pumpAndSettle();

        final mapFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is CountryMapPainter,
        );
        final mapRect = tester.getRect(mapFinder);
        final cities = citiesSeed
            .where((city) => city.country == country)
            .toList();
        final markerRects = [
          for (final city in cities)
            tester.getRect(find.byKey(ValueKey('city-marker-${city.id}'))),
        ];

        expect(markerRects, hasLength(5));
        for (var index = 0; index < markerRects.length; index++) {
          final rect = markerRects[index];
          expect(rect.width, closeTo(48, 0.001));
          expect(rect.height, closeTo(48, 0.001));
          expect(rect.left, greaterThanOrEqualTo(mapRect.left));
          expect(rect.top, greaterThanOrEqualTo(mapRect.top));
          expect(rect.right, lessThanOrEqualTo(mapRect.right));
          expect(rect.bottom, lessThanOrEqualTo(mapRect.bottom));
          expect(
            find.bySemanticsLabel(
              '${cities[index].nameEn}, ${cities[index].nameLocal}',
            ),
            findsOneWidget,
          );
        }
        for (var first = 0; first < markerRects.length; first++) {
          for (var second = first + 1; second < markerRects.length; second++) {
            expect(
              (markerRects[first].center - markerRects[second].center).distance,
              greaterThanOrEqualTo(47.999),
            );
            expect(
              markerRects[first].overlaps(markerRects[second]),
              isFalse,
              reason:
                  '${country.labelEn}: ${cities[first].nameEn} overlaps '
                  '${cities[second].nameEn}',
            );
          }
        }
      }
    },
  );

  testWidgets('close Osaka and Kyoto map markers select their own City', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final observer = _RecordingNavigatorObserver();
    final osaka = citiesSeed.firstWhere((city) => city.nameEn == 'Osaka');
    final kyoto = citiesSeed.firstWhere((city) => city.nameEn == 'Kyoto');
    await tester.pumpWidget(appFor(Country.japan, observers: [observer]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('city-marker-${osaka.id}')));
    await tester.pumpAndSettle();
    expect(observer.routes.last.settings.arguments, same(osaka));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('city-marker-${kyoto.id}')));
    await tester.pumpAndSettle();
    expect(observer.routes.last.settings.arguments, same(kyoto));
  });
}
