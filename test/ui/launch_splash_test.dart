import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/app.dart';
import 'package:kjc_7day_chat/providers.dart';

void main() {
  Widget app() => ProviderScope(
    overrides: [conversationsProvider.overrideWith((ref) async => const [])],
    child: const KjcApp(),
  );

  testWidgets('shows the launch splash before the Travel screen', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    expect(find.text('KJC 7-Day Trip'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-illustration')), findsOneWidget);
    expect(find.text('Where are you going?'), findsNothing);
  });

  testWidgets('opens Travel immediately when the splash is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    await tester.tap(find.byKey(const ValueKey('launch-splash')));
    await tester.pump();

    expect(find.text('Where are you going?'), findsOneWidget);
  });

  testWidgets('opens Travel automatically after two seconds', (tester) async {
    await tester.pumpWidget(app());

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Where are you going?'), findsOneWidget);
  });
}
