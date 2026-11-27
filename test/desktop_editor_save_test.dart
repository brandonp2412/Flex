import 'package:drift/drift.dart' hide isNull;
import 'package:flex/app_fab.dart';
import 'package:flex/database/database.dart';
import 'package:flex/editor_content.dart';

import 'package:flex/graph/exercise_editor_page.dart';
import 'package:flex/plan/edit_plan_page.dart';
import 'package:flex/plan/start_plan_page.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/sets/edit_sets_page.dart';
import 'package:flex/weight_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/fixtures.dart';
import 'support/test_app.dart';

void setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  final editors = <String, Widget Function()>{
    'plan': () => const EditPlanPage(plan: PlansCompanion(days: Value(''))),
    'exercise': () => const ExerciseEditorPage.add(),
    'exercise details': () =>
        const ExerciseEditorPage.edit(name: 'Bench press'),
    'set': () => EditSetPage(exerciseSet: exerciseSetModelFixture()),
    'bulk sets': () => const EditSetsPage(ids: []),
    'body weight': () => const WeightPage(),
  };

  for (final entry in editors.entries) {
    testWidgets('${entry.key} has a fixed top-right desktop Save action', (
      tester,
    ) async {
      setViewport(tester, const Size(1200, 900));
      final harness = await FlexTestHarness.create();
      await harness.pump(tester, entry.value());
      await tester.pumpAndSettle();

      final save = find.byType(DesktopEditorSaveButton);
      expect(save, findsOneWidget);
      expect(find.byType(AppFab), findsNothing);
      expect(
        find.ancestor(of: save, matching: find.byType(AppBar)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('desktop-editor-save')), findsOneWidget);
      final button = find.byKey(const Key('desktop-editor-save'));
      final bar = tester.getRect(find.byType(AppBar));
      final rect = tester.getRect(button);
      expect(bar.right - rect.right, closeTo(16, 1));
      expect(rect.center.dy, closeTo(bar.center.dy, 1));
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(button), rect);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} retains the mobile floating Save action', (
      tester,
    ) async {
      setViewport(tester, const Size(390, 844));
      final harness = await FlexTestHarness.create();
      await harness.pump(tester, entry.value());
      await tester.pumpAndSettle();

      expect(find.byType(DesktopEditorSaveButton), findsNothing);
      expect(find.byType(AppFab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop workout uses the same top-right Save action', (
    tester,
  ) async {
    setViewport(tester, const Size(1200, 900));
    final harness = await FlexTestHarness.create();
    final db = harness.database;
    final id = await db.plans.insertOne(planFixture());
    await insertPlanExerciseFixture(db, planId: id, exercise: 'Stairmaster');
    final plan = await (db.plans.select()..where((p) => p.id.equals(id)))
        .getSingle();
    await harness.pump(tester, StartPlanPage(plan: plan));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('desktop-editor-save'));
    expect(button, findsOneWidget);
    expect(find.text('Save set'), findsOneWidget);
    final bar = tester.getRect(find.byType(AppBar));
    final rect = tester.getRect(button);
    expect(bar.right - rect.right, closeTo(16, 1));
    expect(rect.center.dy, closeTo(bar.center.dy, 1));
  });

  testWidgets('desktop exercise Save submits the entered name', (tester) async {
    setViewport(tester, const Size(1200, 900));
    final harness = await FlexTestHarness.create();
    await harness.pump(tester, const ExerciseEditorPage.add());
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Name'), 'Desktop press');
    final save = find.byKey(const Key('desktop-editor-save'));
    await tester.tap(save);
    await tester.pumpAndSettle();

    final exercise = await (harness.database.select(
      harness.database.exercises,
    )..where((table) => table.name.equals('Desktop press'))).getSingle();
    expect(exercise.name, 'Desktop press');
  });
}
