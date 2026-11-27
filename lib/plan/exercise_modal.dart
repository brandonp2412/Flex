import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/swap_workout.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flex/plan/plan_exercise_settings_dialog.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExerciseModal extends StatelessWidget {
  final PlanExercise planExercise;
  final int exerciseId;
  final String exerciseName;
  final int? workoutId;
  final bool hasData;
  final Function() onSelect;
  final bool inlineActions;

  const ExerciseModal({
    super.key,
    required this.planExercise,
    required this.exerciseId,
    required this.exerciseName,
    required this.workoutId,
    required this.hasData,
    required this.onSelect,
    this.inlineActions = false,
  });

  Widget action({
    required Widget leading,
    required Widget title,
    required VoidCallback onTap,
  }) => inlineActions
      ? TextButton.icon(onPressed: onTap, icon: leading, label: title)
      : ListTile(leading: leading, title: title, onTap: onTap);

  void closeActions(BuildContext context) {
    if (!inlineActions) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: <Widget>[
        action(
          leading: const Icon(Icons.settings),
          title: Text(context.l10n.navSettings),
          onTap: () {
            final rootContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            closeActions(context);
            showDialog(
              context: rootContext,
              builder: (context) => PlanExerciseSettingsDialog(
                name: exerciseName,
                initial: planExercise.toCompanion(false),
                onChanged: (patch) =>
                    (db.planExercises.update()
                          ..where((row) => row.id.equals(planExercise.id)))
                        .write(patch),
              ),
            );
          },
        ),
        if (hasData)
          action(
            leading: const Icon(Icons.edit),
            title: Text(context.l10n.actionEdit),
            onTap: () async {
              closeActions(context);
              final workoutId = this.workoutId;
              if (workoutId == null) return;
              final exerciseSet = await ExerciseSetQuery(
                db,
                workoutId: workoutId,
                exerciseId: exerciseId,
              ).firstOrNull();
              if (exerciseSet == null) return;
              if (!context.mounted) return;
              await Navigator.of(context).push(
                FlexPageRoute(
                  builder: (context) => EditSetPage(exerciseSet: exerciseSet),
                ),
              );
              onSelect();
            },
          ),
        if (hasData)
          action(
            leading: const Icon(Icons.undo),
            title: Text(context.l10n.actionUndo),
            onTap: () async {
              closeActions(context);
              final workoutId = this.workoutId;
              if (workoutId == null) return;
              final exerciseSet = await ExerciseSetQuery(
                db,
                workoutId: workoutId,
                exerciseId: exerciseId,
              ).firstOrNull();
              if (exerciseSet == null) return;
              await deleteExerciseSets(db, [exerciseSet.id]);
              if (!context.mounted) return;
              onSelect();
              final timerState = context.read<TimerState>();
              timerState.stopTimer();
            },
          ),
        if (!hasData)
          action(
            leading: const Icon(Icons.swap_horiz),
            title: Text(context.l10n.actionSwap),
            onTap: () async {
              final navigator = Navigator.of(context);
              if (!inlineActions) navigator.pop();
              final result = await navigator.push(
                FlexPageRoute(
                  builder: (context) =>
                      SwapWorkout(planExerciseId: planExercise.id),
                ),
              );
              if (result == true) {
                onSelect();
              }
            },
          ),
      ],
    );
  }
}
