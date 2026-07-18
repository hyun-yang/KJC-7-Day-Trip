import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/ui/home/home_screen.dart';

void main() {
  testWidgets('Travel shows exactly three country cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.byKey(const ValueKey('country-card-KR')), findsOneWidget);
    expect(find.byKey(const ValueKey('country-card-JP')), findsOneWidget);
    expect(find.byKey(const ValueKey('country-card-CN')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('country-card-'),
      ),
      findsNWidgets(3),
    );
    expect(find.text('Korea'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('China'), findsOneWidget);
    expect(find.text('한국'), findsNothing);
    expect(find.text('日本'), findsNothing);
    expect(find.text('中国'), findsNothing);
  });

  testWidgets('choosing Japan opens the Japan map', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );

    await tester.tap(find.byKey(const ValueKey('country-card-JP')));
    await tester.pumpAndSettle();

    expect(find.text('Explore Japan'), findsOneWidget);
  });
}
