import 'package:drift/drift.dart' hide isNull;
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/import_data.dart';
import 'package:flex/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tests.dart';

void main() {
  test(
    'failed plan CSV replacement rolls back plans and exercise definitions',
    () async {
      final database = testDb();
      addTearDown(database.close);
      await database.planExercises.deleteAll();
      await database.plans.deleteAll();
      await database.plans.insertOne(
        PlansCompanion.insert(id: const Value(99), days: 'Sunday'),
      );
      final originalExercise = await createExerciseDefinition(
        database,
        name: 'Rollback original exercise',
        cardio: false,
        displayUnit: 'kg',
      );
      await database.planExercises.insertOne(
        PlanExercisesCompanion.insert(
          planId: 99,
          exerciseId: originalExercise.id,
          enabled: true,
        ),
      );

      final duplicateIds =
          'id,days,title,sequence,exercises\n'
          '42,Monday,New,1,Rollback imported A\n'
          '42,Tuesday,Duplicate,2,Rollback imported B\n';

      await expectLater(
        replacePlansFromCsv(database, duplicateIds, AppLocalizationsEn()),
        throwsA(isA<Exception>()),
      );

      final plans = await database.plans.select().get();
      final links = await database.planExercises.select().get();
      expect(plans, hasLength(1));
      expect(plans.single.id, 99);
      expect(links, hasLength(1));
      expect(links.single.planId, 99);
      expect(links.single.exerciseId, originalExercise.id);
      expect(await getExerciseByName(database, 'Rollback imported A'), isNull);
      expect(await getExerciseByName(database, 'Rollback imported B'), isNull);
    },
  );

  test('successful plan CSV replacement restores all plan links', () async {
    final database = testDb();
    addTearDown(database.close);
    await database.planExercises.deleteAll();
    await database.plans.deleteAll();

    final csv =
        'id,days,title,sequence,exercises\n'
        '42,Monday,Round trip,1,Plan link A;Plan link B\n';

    final imported = await replacePlansFromCsv(
      database,
      csv,
      AppLocalizationsEn(),
    );
    expect(imported.plans, 1);
    expect(imported.links, 2);
    final plans = await database.plans.select().get();
    final links = await database.planExercises.select().get();
    expect(plans.single.id, 42);
    expect(plans.single.title, 'Round trip');
    expect(links, hasLength(2));
    expect(links.every((link) => link.planId == 42), isTrue);
  });
}
