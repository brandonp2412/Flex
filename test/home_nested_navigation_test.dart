import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/plan/plans_page.dart';
import 'package:flex/home_page.dart';
import 'package:flex/settings/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('desktop graphs settings can return after appearance', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = await FlexTestHarness.create();
    await harness.database.settings.update().write(
      const SettingsCompanion(tabs: Value('GraphsPage')),
    );
    await harness.pump(
      tester,
      const HomePage(),
      surfaceSize: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('desktop-search-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceSettings), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Search...'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Search graphs...'), findsOneWidget);
    expect(find.byType(DesktopNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.byType(DesktopNav), findsOneWidget);
    expect(find.byType(AppearanceSettings), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Search...'), findsOneWidget);
    expect(find.byType(DesktopNav), findsOneWidget);

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

  testWidgets('desktop resize preserves the selected mobile tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final harness = await FlexTestHarness.create();
    await harness.database.settings.update().write(
      const SettingsCompanion(tabs: Value('HistoryPage,GraphsPage')),
    );
    await harness.pump(tester, const HomePage());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('GraphsPage')));
    await tester.pumpAndSettle();
    expect(find.text('Search graphs...'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();

    expect(find.byType(DesktopNav), findsOneWidget);
    expect(find.text('Search graphs...'), findsOneWidget);
    expect(find.text('Search history...'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
