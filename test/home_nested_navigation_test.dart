import 'package:flex/graph/exercise_editor_page.dart';
import 'package:flex/graph/graph_notes_page.dart';
import 'package:flex/graph/global_progress_page.dart';
import 'package:flex/graph/graphs_page.dart';
import 'package:flutter/gestures.dart';
import '../integration_test/support/fixtures.dart';
import 'package:flex/settings/settings_category_page.dart';
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/plan/plans_page.dart';
import 'package:flex/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('desktop graph actions stay inside the Graphs tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = await FlexTestHarness.create();
    await harness.database.settings.update().write(
      const SettingsCompanion(
        tabs: Value('GraphsPage,PlansPage'),
        showGlobalProgress: Value(true),
        showNotes: Value(true),
        peekGraph: Value(false),
      ),
    );
    await insertExerciseSetFixture(
      harness.database,
      'Bench press',
      reps: 8,
      weight: 60,
      created: DateTime(2026, 11, 1),
    );
    await harness.pump(
      tester,
      const HomePage(),
      surfaceSize: const Size(1200, 800),
    );
    await tester.pumpAndSettle();
    final graphs = tester.state<GraphsPageState>(find.byType(GraphsPage));
    final navigator = graphs.navKey.currentState!;
    final root = Navigator.of(graphs.context);

    void expectInTab(Finder page) {
      expect(page, findsOneWidget);
      expect(Navigator.of(tester.element(page)), same(navigator));
      expect(root.canPop(), isFalse);
      expect(find.byType(DesktopNav), findsOneWidget);
    }

    await tester.tapAt(
      tester.getCenter(find.text('Bench press')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expectInTab(find.byType(ExerciseEditorPage));
    navigator.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('desktop-select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desktop-edit')));
    await tester.pumpAndSettle();
    expectInTab(find.byType(ExerciseEditorPage));
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desktop-clear-selection')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Global progress'));
    await tester.pumpAndSettle();
    expectInTab(find.byType(GlobalProgressPage));
    navigator.pop();
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Global progress')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(root.canPop(), isFalse);
    expect(navigator.canPop(), isTrue);
    navigator.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench press'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.readOnly,
      ),
    );
    await tester.pumpAndSettle();
    expectInTab(find.byType(GraphNotesPage));
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Search graphs...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsCategoryPage &&
            widget.category == SettingsCategory.appearance,
      ),
      findsOneWidget,
    );
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsCategoryPage &&
            widget.category == SettingsCategory.appearance,
      ),
      findsOneWidget,
    );
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
