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
    expect(find.byKey(const ValueKey('splash-background')), findsNothing);
    expect(find.byKey(const ValueKey('splash-illustration')), findsOneWidget);
    expect(find.text('Where are you going?'), findsNothing);

    final title = tester.getRect(find.text('KJC 7-Day Trip'));
    final illustration = tester.getRect(
      find.byKey(const ValueKey('splash-illustration')),
    );
    expect(title.center.dx, closeTo(illustration.center.dx, 1));
    expect(title.bottom, lessThan(illustration.top));
  });

  testWidgets('separates the title and illustration with a 32px gap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());

    final title = tester.getRect(find.text('KJC 7-Day Trip'));
    final illustration = tester.getRect(
      find.byKey(const ValueKey('splash-illustration')),
    );

    expect(title.center.dx, closeTo(illustration.center.dx, 1));
    expect(illustration.top - title.bottom, closeTo(32, 0.01));
  });

  testWidgets('shrinks only the illustration on a short screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());

    final title = tester.getRect(find.text('KJC 7-Day Trip'));
    final illustration = tester.getRect(
      find.byKey(const ValueKey('splash-illustration')),
    );

    expect(illustration.top - title.bottom, closeTo(32, 0.01));
    expect(title.center.dx, closeTo(illustration.center.dx, 1));
    expect((title.top + illustration.bottom) / 2, closeTo(160, 1));
    expect(illustration.width / illustration.height, closeTo(390 / 280, 0.01));
    expect(illustration.width, lessThan(326));
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
