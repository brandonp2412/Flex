import 'package:drift/drift.dart' hide isNull;
import 'package:flex/app_fab.dart';
import 'package:flex/database/database.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/graph/add_exercise_page.dart';
import 'package:flex/graph/edit_graph_page.dart';
import 'package:flex/plan/edit_plan_page.dart';
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
    'exercise': () => const AddExercisePage(),
    'exercise details': () => const EditGraphPage(name: 'Bench press'),
    'set': () => EditSetPage(exerciseSet: exerciseSetModelFixture()),
    'bulk sets': () => const EditSetsPage(ids: []),
    'body weight': () => const WeightPage(),
  };

  for (final entry in editors.entries) {
    testWidgets(
      '${entry.key} has a large Save action after desktop form fields',
      (tester) async {
        setViewport(tester, const Size(1200, 900));
        final harness = await FlexTestHarness.create();
        await harness.pump(tester, entry.value());
        await tester.pumpAndSettle();

        final save = find.byType(DesktopEditorSaveButton);
        await tester.scrollUntilVisible(
          find.byKey(const Key('desktop-editor-save')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(save, findsOneWidget);
        expect(find.byType(AppFab), findsNothing);
        expect(
          find.ancestor(of: save, matching: find.byType(ListView)),
          findsOneWidget,
        );
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        final size = tester.getSize(save);
        expect(size.height, greaterThanOrEqualTo(56));
        expect(size.width, greaterThan(400));
        expect(find.byKey(const Key('desktop-editor-save')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

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

  testWidgets('desktop exercise Save submits the entered name', (tester) async {
    setViewport(tester, const Size(1200, 900));
    final harness = await FlexTestHarness.create();
    await harness.pump(tester, const AddExercisePage());
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Name'), 'Desktop press');
    final save = find.byKey(const Key('desktop-editor-save'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    final exercise = await (harness.database.select(
      harness.database.exercises,
    )..where((table) => table.name.equals('Desktop press'))).getSingle();
    expect(exercise.name, 'Desktop press');
  });
}
