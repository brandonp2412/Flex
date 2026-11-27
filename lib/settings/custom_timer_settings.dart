import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flutter/material.dart';

import 'package:flex/duration_input.dart';

class CustomTimerSettings extends StatefulWidget {
  const CustomTimerSettings({super.key});

  @override
  State<CustomTimerSettings> createState() => _CustomTimerSettingsState();
}

class _CustomTimerSettingsState extends State<CustomTimerSettings> {
  List<Exercise> _customExercises = [];
  final _fields = <int, DurationInput>{};

  @override
  void initState() {
    super.initState();
    _loadExercisesWithCustomTimers();
  }

  Future<void> _loadExercisesWithCustomTimers() async {
    final exercises =
        await (db.exercises.select()
              ..where(
                (exercise) =>
                    exercise.defaultRestDurationMs.isNotNull() &
                    exercise.archived.equals(false),
              )
              ..orderBy([(exercise) => OrderingTerm.asc(exercise.name)]))
            .get();
    if (!mounted) return;

    setState(() {
      _customExercises = exercises;

      for (final exercise in exercises) {
        _fields[exercise.id] = DurationInput(
          initial: Duration(milliseconds: exercise.defaultRestDurationMs!),
        );
      }
    });
  }

  Future<void> _updateExerciseRestTime(
    int exerciseId,
    Duration duration,
  ) async {
    final durationMs = duration > Duration.zero
        ? duration.inMilliseconds
        : null;
    await (db.exercises.update()
          ..where((exercise) => exercise.id.equals(exerciseId)))
        .write(ExercisesCompanion(defaultRestDurationMs: Value(durationMs)));
    if (!mounted || durationMs != null) return;
    final input = _fields.remove(exerciseId);
    setState(() => _customExercises.removeWhere((e) => e.id == exerciseId));
    WidgetsBinding.instance.addPostFrameCallback((_) => input?.dispose());
  }

  Widget _buildPerExerciseSection() {
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
          ..._customExercises.map((exercise) {
            final fields = _fields[exercise.id];
            if (fields == null) return const SizedBox();

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
                          onPressed: () => _updateExerciseRestTime(
                            exercise.id,
                            Duration.zero,
                          ),
                          tooltip: context.l10n.removeCustomTimer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    fields.settingsFields(
                      context,
                      minutesLabel: context.l10n.minutesLabel,
                      gap: 12,
                      onChanged: (duration) =>
                          _updateExerciseRestTime(exercise.id, duration),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _customExercises.isEmpty
      ? const SizedBox.shrink()
      : _buildPerExerciseSection();

  @override
  void dispose() {
    for (final fields in _fields.values) {
      fields.dispose();
    }
    super.dispose();
  }
}
