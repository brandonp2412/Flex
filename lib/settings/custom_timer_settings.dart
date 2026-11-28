import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/error_state.dart';
import 'package:flex/main.dart';
import 'package:flutter/material.dart';

import 'package:flex/duration_input.dart';

class CustomTimerSettings extends StatefulWidget {
  const CustomTimerSettings({super.key});

  @override
  State<CustomTimerSettings> createState() => _CustomTimerSettingsState();
}

class _CustomTimerSettingsState extends State<CustomTimerSettings> {
  late final _exercises =
      (db.exercises.select()
            ..where(
              (exercise) =>
                  exercise.defaultRestDurationMs.isNotNull() &
                  exercise.archived.equals(false),
            )
            ..orderBy([(exercise) => OrderingTerm.asc(exercise.name)]))
          .watch();

  Widget _buildPerExerciseSection(List<Exercise> exercises) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.fitness_center),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.perExerciseRestTimes,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.perExerciseRestTimesDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          for (final exercise in exercises)
            _ExerciseTimerField(key: ValueKey(exercise.id), exercise: exercise),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _exercises,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const AppErrorState();
      final exercises = snapshot.data;
      return exercises == null || exercises.isEmpty
          ? const SizedBox.shrink()
          : _buildPerExerciseSection(exercises);
    },
  );
}

class _ExerciseTimerField extends StatelessWidget {
  const _ExerciseTimerField({super.key, required this.exercise});

  final Exercise exercise;

  Future<void> _update(Duration duration) =>
      (db.exercises.update()..where((row) => row.id.equals(exercise.id))).write(
        ExercisesCompanion(
          defaultRestDurationMs: Value(
            duration > Duration.zero ? duration.inMilliseconds : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _update(Duration.zero),
                  tooltip: context.l10n.removeCustomTimer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DurationSettingsFields(
              duration: Duration(milliseconds: exercise.defaultRestDurationMs!),
              minutesLabel: context.l10n.minutesLabel,
              gap: 12,
              onChanged: _update,
            ),
          ],
        ),
      ),
    );
  }
}
