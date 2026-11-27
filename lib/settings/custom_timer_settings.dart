import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flutter/material.dart';

import 'package:flex/settings/timer_settings.dart';

class CustomTimerSettings extends StatefulWidget {
  const CustomTimerSettings({super.key});

  @override
  State<CustomTimerSettings> createState() => _CustomTimerSettingsState();
}

class _CustomTimerSettingsState extends State<CustomTimerSettings> {
  List<Exercise> _customExercises = [];
  final Map<String, TextEditingController> _minuteFields = {};
  final Map<String, TextEditingController> _secondFields = {};

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

      for (final result in exercises) {
        final exerciseName = result.name;
        final restMs = result.defaultRestDurationMs;
        if (restMs != null) {
          final duration = Duration(milliseconds: restMs);
          _minuteFields[exerciseName] = TextEditingController(
            text: duration.inMinutes.toString(),
          );
          _secondFields[exerciseName] = TextEditingController(
            text: (duration.inSeconds % 60).toString(),
          );
        }
      }
    });
  }

  Future<void> _updateExerciseRestTime(
    String exerciseName,
    int? minutes,
    int? seconds,
  ) async {
    Duration? duration;
    final mins = minutes ?? 0;
    final secs = seconds ?? 0;

    if (mins > 0 || secs > 0) {
      duration = Duration(minutes: mins, seconds: secs);
    }

    await (db.exercises.update()
          ..where((exercise) => exercise.name.equals(exerciseName)))
        .write(
          ExercisesCompanion(
            defaultRestDurationMs: Value(duration?.inMilliseconds),
          ),
        );

    if (!mounted) return;
    if (duration == null) {
      _minuteFields.remove(exerciseName)?.dispose();
      _secondFields.remove(exerciseName)?.dispose();
      setState(() {
        _customExercises.removeWhere((e) => e.name == exerciseName);
      });
    }
  }

  Future<void> _removeCustomTimer(String exerciseName) =>
      _updateExerciseRestTime(exerciseName, null, null);

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
            final exerciseName = exercise.name;
            if (_minuteFields[exerciseName] == null ||
                _secondFields[exerciseName] == null)
              return const SizedBox();
            final minController = _minuteFields[exerciseName]!;
            final secController = _secondFields[exerciseName]!;

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
                            exerciseName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeCustomTimer(exerciseName),
                          tooltip: context.l10n.removeCustomTimer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    timerDurationFields(
                      context,
                      minController,
                      secController,
                      minutesLabel: context.l10n.minutesLabel,
                      gap: 12,
                      onMinutes: (minutes) => _updateExerciseRestTime(
                        exerciseName,
                        minutes,
                        int.tryParse(secController.text) ?? 0,
                      ),
                      onSeconds: (seconds) => _updateExerciseRestTime(
                        exerciseName,
                        int.tryParse(minController.text) ?? 0,
                        seconds,
                      ),
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
    for (final controller in _minuteFields.values) {
      controller.dispose();
    }
    for (final controller in _secondFields.values) {
      controller.dispose();
    }

    super.dispose();
  }
}
