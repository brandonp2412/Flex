import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/plan/plan_exercise_settings_dialog.dart';
import 'package:flutter/material.dart';

class ExerciseTile extends StatelessWidget {
  final PlanExercisesCompanion planExercise;
  final String exerciseName;
  final Function(PlanExercisesCompanion) onChange;

  const ExerciseTile({
    super.key,
    required this.onChange,
    required this.planExercise,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconButton(
        tooltip: context.l10n.navSettings,
        icon: const Icon(Icons.settings),
        onPressed: () {
          var current = planExercise;
          showDialog(
            context: context,
            builder: (context) => PlanExerciseSettingsDialog(
              name: exerciseName,
              initial: current,
              draft: true,
              onChanged: (patch) {
                current = current.copyWith(
                  enabled: patch.enabled.present
                      ? patch.enabled
                      : current.enabled,
                  maxSets: patch.maxSets.present
                      ? patch.maxSets
                      : current.maxSets,
                  warmupSets: patch.warmupSets.present
                      ? patch.warmupSets
                      : current.warmupSets,
                  timers: patch.timers.present ? patch.timers : current.timers,
                );
                onChange(current);
              },
            ),
          );
        },
      ),
      title: Text(exerciseName),
      trailing: Switch(
        value: planExercise.enabled.value,
        onChanged: (value) {
          onChange(planExercise.copyWith(enabled: Value(value)));
        },
      ),
      onTap: () {
        onChange(
          planExercise.copyWith(enabled: Value(!planExercise.enabled.value)),
        );
      },
    );
  }
}
