import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/plan_exercise_settings_dialog.dart';
import 'package:flex/plan/swap_workout.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExerciseModal extends StatelessWidget {
  final PlanExercise planExercise;
  final String exerciseName;
  final int? workoutId;
  final bool hasData;
  final Function() onSelect;
  final bool inlineActions;

  const ExerciseModal({
    super.key,
    required this.planExercise,
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
          for (final (icon, title, undo) in [
            (Icons.edit, context.l10n.actionEdit, false),
            (Icons.undo, context.l10n.actionUndo, true),
          ])
            action(
              leading: Icon(icon),
              title: Text(title),
              onTap: () => _editOrUndo(context, undo: undo),
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

  Future<void> _editOrUndo(BuildContext context, {required bool undo}) async {
    final navigator = Navigator.of(context);
    final timer = undo ? context.read<TimerState>() : null;
    closeActions(context);
    final workoutId = this.workoutId;
    if (workoutId == null) return;
    final set = await ExerciseSetQuery(
      db,
      workoutId: workoutId,
      exerciseId: planExercise.exerciseId,
    ).firstOrNull();
    if (set == null || !navigator.mounted) return;
    if (undo) {
      await deleteExerciseSets(db, [set.id]);
      if (!navigator.mounted) return;
      timer!.stopTimer();
    } else {
      await navigator.push(
        FlexPageRoute(builder: (_) => EditSetPage(exerciseSet: set)),
      );
    }
    if (navigator.mounted) onSelect();
  }
}
