import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/error_state.dart';
import 'package:flex/graph/add_exercise_page.dart';
import 'package:flex/image_field.dart';
import 'package:flex/set_summary.dart';
import 'package:flex/weight_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tests.dart';
import 'support/test_app.dart';

void main() {
  test('exercise catalog writes to the supplied database', () async {
    final harness = await FlexTestHarness.create();
    final otherDatabase = testDb();
    addTearDown(otherDatabase.close);
    addTearDown(harness.database.close);

    final exercise = await createExerciseDefinition(
      otherDatabase,
      name: 'Independent exercise',
      cardio: true,
      displayUnit: 'm',
      category: 'Independent category',
    );

    expect(
      await getExerciseCategoryName(otherDatabase, exercise),
      'Independent category',
    );
    expect(await getExerciseByName(harness.database, exercise.name), isNull);
    expect(
      await (harness.database.categories.select()
            ..where((row) => row.name.equals('Independent category')))
          .get(),
      isEmpty,
    );
  });

  testWidgets('body weight confirms discard and saves without a warning', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const WeightPage())),
            child: const Text('Open weight'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '75');
    await tester.pump();
    await Navigator.of(tester.element(find.byType(WeightPage))).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('75'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Open weight'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsNothing);
    expect(
      (await harness.database.bodyWeights.select().get()).single.weightKg,
      75,
    );
  });

  testWidgets('image removal is visible on a phone and clears the preview', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    String? path = '/missing-image.png';
    await harness.pump(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AppImageField(
            path: path,
            onPick: () {},
            onRemove: () => setState(() => path = null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remove image'), findsOneWidget);
    await tester.tap(find.text('Remove image'));
    await tester.pumpAndSettle();
    expect(path, isNull);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'exercise creation offers metres and calories within a constrained form',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final harness = await FlexTestHarness.create();
      await harness.pump(
        tester,
        const AddExercisePage(),
        surfaceSize: const Size(1400, 900),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<DropdownButton<String>>(
        find.byWidgetPredicate((widget) => widget is DropdownButton<String>),
      );
      expect(
        field.items!.map((item) => item.value),
        containsAll(['m', 'kcal']),
      );
      expect(tester.getSize(find.byType(EditorContent)).width, 1400);
      expect(tester.getSize(find.byType(Form)).width, lessThanOrEqualTo(720));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'set summaries include metre duration and share strength ordering',
    (tester) async {
      final harness = await FlexTestHarness.create();
      await harness.pump(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              Text(
                formatSetSummary(
                  context,
                  unitCode: 'm',
                  cardio: true,
                  weight: 0,
                  reps: 0,
                  distance: 400,
                  duration: 1.5,
                  incline: 2,
                ),
              ),
              Text(
                formatSetSummary(
                  context,
                  unitCode: 'kg',
                  cardio: false,
                  weight: 90,
                  reps: 5,
                  distance: 0,
                  duration: 0,
                ),
              ),
              const AppErrorState(),
            ],
          ),
        ),
      );
      expect(find.text('400 m / 1:30 @ 2%'), findsOneWidget);
      expect(find.text('5 × 90 kg'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(ErrorWidget), findsNothing);
    },
  );
}
