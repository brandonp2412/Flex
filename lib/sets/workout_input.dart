import 'package:drift/drift.dart' show Value;
import 'package:flex/database/exercise_set_view.dart';
import 'package:flex/database/set_performance.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/sets/workout_number_field.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

class WorkoutInput {
  WorkoutInput({bool session = false})
    : reps = TextEditingController(text: session ? '0.0' : ''),
      weight = TextEditingController(text: session ? '0.0' : ''),
      distance = TextEditingController(text: session ? '0.0' : ''),
      minutes = TextEditingController(text: session ? '0.0' : ''),
      seconds = TextEditingController(text: session ? '0.0' : ''),
      incline = TextEditingController(text: session ? '0' : '');

  final TextEditingController reps, weight, distance, minutes, seconds, incline;

  Iterable<TextEditingController> get controllers => [
    reps,
    weight,
    distance,
    minutes,
    seconds,
    incline,
  ];

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  void clear() {
    for (final controller in controllers) {
      controller.text = '0';
    }
  }

  void fill(SetPerformance set, {bool preserveZeroFields = false}) {
    if (!preserveZeroFields || set.reps != 0) reps.text = toString(set.reps);
    weight.text = toString(set.weight);
    if (!preserveZeroFields || set.distance != 0)
      distance.text = toString(set.distance);
    if (!preserveZeroFields || set.duration != 0) {
      minutes.text = set.duration.floor().toString();
      seconds.text = ((set.duration * 60) % 60).floor().toString();
    }
    if (!preserveZeroFields || (set.incline != null && set.incline != 0)) {
      incline.text = set.incline?.toString() ?? '0';
    }
  }

  double get duration =>
      (int.tryParse(seconds.text) ?? 0) / 60 +
      (int.tryParse(minutes.text) ?? 0);

  ExerciseSetView apply(BuildContext context, ExerciseSetView original) =>
      snapshot(context)(original);

  ExerciseSetView Function(ExerciseSetView) snapshot(
    BuildContext context, {
    bool partial = false,
  }) {
    final parsedReps = parseDisplayNumber(context, reps.text);
    final parsedWeight = parseDisplayNumber(context, weight.text);
    final parsedDistance = parseDisplayNumber(context, distance.text);
    final parsedDuration =
        partial && seconds.text.isEmpty && minutes.text.isEmpty
        ? null
        : duration;
    final parsedIncline = partial && incline.text.isEmpty
        ? const Value<int?>.absent()
        : Value(int.tryParse(incline.text));
    return (original) => original.copyWith(
      reps: parsedReps,
      weight: parsedWeight,
      distance: parsedDistance,
      duration: parsedDuration,
      incline: parsedIncline,
    );
  }

  Widget durationFields(
    BuildContext context, {
    String? minutesHint,
    String? secondsHint,
    FocusNode? minutesFocus,
    FocusNode? secondsFocus,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onMinutesSubmitted,
    ValueChanged<String>? onSecondsSubmitted,
  }) => Row(
    children: [
      Expanded(
        child: WorkoutNumberField(
          controller: minutes,
          focusNode: minutesFocus,
          decoration: InputDecoration(
            labelText: context.l10n.minutesLabel,
            hintText: minutesHint,
          ),
          integer: true,
          onChanged: onChanged,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: onMinutesSubmitted,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: WorkoutNumberField(
          controller: seconds,
          focusNode: secondsFocus,
          decoration: InputDecoration(
            labelText: context.l10n.secondsLabel,
            hintText: secondsHint,
          ),
          integer: true,
          onChanged: onChanged,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: onSecondsSubmitted,
        ),
      ),
    ],
  );
}
