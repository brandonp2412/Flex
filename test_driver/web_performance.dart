import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';
import 'package:flex/main.dart' as app;
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Uri.base.queryParameters['seed'] == '1') {
    await seedPerformanceData(app.db);
  }
  await app.main();
}

Future<void> seedPerformanceData(AppDatabase database) async {
  const marker = 'Perf fixture 000';
  final existing =
      await (database.exercises.select()
            ..where((exercise) => exercise.name.equals(marker)))
          .getSingleOrNull();
  if (existing != null) return;

  await database.transaction(() async {
    final ids = <int>[];
    for (var index = 0; index < 120; index++) {
      final exercise = await database.exercises.insertReturning(
        ExercisesCompanion.insert(
          name: 'Perf fixture ${index.toString().padLeft(3, '0')}',
          kind: 'strength',
          displayUnit: 'kg',
        ),
      );
      ids.add(exercise.id);
    }

    final plans = <int>[];
    for (var index = 0; index < 24; index++) {
      final plan = await database.plans.insertReturning(
        PlansCompanion.insert(
          days: ['Monday', 'Wednesday', 'Friday'][index % 3],
          title: Value('Perf plan ${index + 1}'),
          sequence: Value(index),
        ),
      );
      plans.add(plan.id);
    }

    await database.batch((batch) {
      for (var plan = 0; plan < plans.length; plan++) {
        for (var slot = 0; slot < 8; slot++) {
          batch.insert(
            database.planExercises,
            PlanExercisesCompanion.insert(
              planId: plans[plan],
              exerciseId: ids[(plan * 8 + slot) % ids.length],
              enabled: true,
              sequence: Value(slot),
            ),
          );
        }
      }
      final today = DateTime(2026, 11, 1, 12);
      for (var index = 0; index < 7200; index++) {
        batch.insert(
          database.exerciseSets,
          ExerciseSetsCompanion.insert(
            exerciseId: ids[index % ids.length],
            timestamp: today.subtract(Duration(hours: index * 3)),
            reps: Value(4.0 + index % 12),
            loadKg: Value(20.0 + (index % 120)),
          ),
        );
      }
    });

    await database.settings.update().write(
      const SettingsCompanion(
        tabs: Value('HistoryPage,PlansPage,GraphsPage,TimerPage,SettingsPage'),
        localeOverride: Value('en'),
        notifications: Value(false),
        restTimers: Value(false),
        explainedPermissions: Value(true),
        notificationPermissionRequested: Value(true),
      ),
    );
  });
}
