import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/application/generation_selection.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:kjc_7day_chat/ui/category/category_screen.dart';
import 'package:kjc_7day_chat/ui/generation/generation_screen.dart';

void main() {
  final tokyo = citiesSeed.firstWhere((city) => city.nameEn == 'Tokyo');

  Widget app() => MaterialApp(home: CategoryScreen(city: tokyo));

  testWidgets('shows the city and exactly eleven category controls', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    expect(find.text('Tokyo'), findsWidgets);
    expect(find.textContaining('東京'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('category-'),
      ),
      findsNWidgets(11),
    );
    for (final category in kPhraseCatalog) {
      expect(find.text(category.labelEn), findsOneWidget);
    }
  });

  testWidgets('all fifty-nine subtopics are discoverable', (tester) async {
    await tester.pumpWidget(app());

    for (final category in kPhraseCatalog) {
      final categoryFinder = find.byKey(ValueKey('category-${category.id}'));
      await tester.ensureVisible(categoryFinder);
      await tester.pumpAndSettle();
      await tester.tap(categoryFinder);
      await tester.pumpAndSettle();
    }

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('subtopic-'),
      ),
      findsNWidgets(59),
    );
  });

  testWidgets('Hotel expansion reveals five English subtopics', (tester) async {
    final hotel = kPhraseCatalog.firstWhere((item) => item.id == 'hotel');
    await tester.pumpWidget(app());

    await tester.tap(find.byKey(const ValueKey('category-hotel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('category-panel-hotel')), findsOneWidget);
    for (final subtopic in hotel.subtopics) {
      expect(find.text(subtopic.labelEn), findsOneWidget);
    }
  });

  testWidgets('Check-in passes the exact selected objects to generation', (
    tester,
  ) async {
    final hotel = kPhraseCatalog.firstWhere((item) => item.id == 'hotel');
    final checkIn = hotel.subtopics.firstWhere((item) => item.id == 'check-in');
    await tester.pumpWidget(app());

    await tester.tap(find.byKey(const ValueKey('category-hotel')));
    await tester.pumpAndSettle();
    final checkInFinder = find.byKey(const ValueKey('subtopic-hotel-check-in'));
    await tester.ensureVisible(checkInFinder);
    await tester.pumpAndSettle();
    await tester.tap(checkInFinder);
    await tester.pumpAndSettle();

    final screen = tester.widget<GenerationScreen>(
      find.byType(GenerationScreen),
    );
    final GenerationSelection selection = screen.selection;
    expect(selection.city, same(tokyo));
    expect(selection.category, same(hotel));
    expect(selection.subtopic, same(checkIn));
    expect(
      find.text('Check-in (with or without a reservation)'),
      findsOneWidget,
    );
    expect(find.text('Tokyo · Hotel'), findsOneWidget);
  });

  testWidgets('returning from generation keeps Hotel expanded', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.byKey(const ValueKey('category-hotel')));
    await tester.pumpAndSettle();
    final checkInFinder = find.byKey(const ValueKey('subtopic-hotel-check-in'));
    await tester.ensureVisible(checkInFinder);
    await tester.pumpAndSettle();
    await tester.tap(checkInFinder);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('category-panel-hotel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('subtopic-hotel-check-in')),
      findsOneWidget,
    );
  });
}
