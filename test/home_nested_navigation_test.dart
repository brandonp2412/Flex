import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/plan/plans_page.dart';
import 'package:flex/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('desktop sidebar keeps Settings at its bottom', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = await FlexTestHarness.create();
    await harness.database.settings.update().write(
      const SettingsCompanion(tabs: Value('PlansPage')),
    );
    await harness.pump(
      tester,
      const HomePage(),
      surfaceSize: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    final settings = find.byKey(const Key('desktop-settings'));
    final plans = find.byKey(const Key('PlansPage'));
    expect(settings, findsOneWidget);
    expect(plans, findsOneWidget);
    expect(
      tester.getTopLeft(settings).dy,
      greaterThan(tester.getBottomLeft(plans).dy + 100),
    );

    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Search...'), findsWidgets);
    await tester.tap(plans);
    await tester.pumpAndSettle();
    expect(find.text('Search plans...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab dock stays visible on nested pages', (tester) async {
    final harness = await FlexTestHarness.create();
    await harness.database.settings.update().write(
      const SettingsCompanion(tabs: Value('PlansPage')),
    );
    await harness.pump(
      tester,
      const HomePage(),
      surfaceSize: const Size(360, 780),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomNav), findsOneWidget);

    final plans = tester.state<PlansPageState>(find.byType(PlansPage));
    plans.navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Start Plan')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start Plan'), findsOneWidget);
    expect(find.byType(BottomNav), findsOneWidget);

    plans.navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(BottomNav), findsOneWidget);
  });
}
