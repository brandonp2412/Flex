import 'package:drift/drift.dart' show Value;
import 'package:flex/database/exercise_set_view.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/sets/workout_number_field.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

enum WorkoutMetric { reps, weight, distance, minutes, seconds, incline }

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

  void fill(ExerciseSetView set, {bool preserveZeroFields = false}) {
    if (!preserveZeroFields || set.reps != 0) reps.text = toString(set.reps);
    weight.text = toString(set.weight);
    if (!preserveZeroFields || set.distance != 0)
      distance.text = toString(set.distance);
    if (!preserveZeroFields || set.duration != 0) {
      minutes.text = set.duration.floor().toString();
      seconds.text = ((set.duration * 60) % 60).floor().toString();
    }
    if (!preserveZeroFields || (set.incline != null && set.incline != 0)) {
      incline.text = set.incline == null ? '0' : toString(set.incline!);
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
        ? const Value<double?>.absent()
        : Value(parseDisplayNumber(context, incline.text));
    return (original) => original.copyWith(
      reps: parsedReps,
      weight: parsedWeight,
      distance: parsedDistance,
      duration: parsedDuration,
      incline: parsedIncline,
    );
  }

  WorkoutNumberField field(
    BuildContext context,
    WorkoutMetric metric, {
    String? label,
    String? hint,
    FocusNode? focus,
    double? step,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    TextInputAction? action,
  }) {
    final (controller, defaultLabel) = switch (metric) {
      WorkoutMetric.reps => (reps, context.l10n.repsLabel),
      WorkoutMetric.weight => (weight, context.l10n.weightLabel),
      WorkoutMetric.distance => (distance, context.l10n.distanceLabel),
      WorkoutMetric.minutes => (minutes, context.l10n.minutesLabel),
      WorkoutMetric.seconds => (seconds, context.l10n.secondsLabel),
      WorkoutMetric.incline => (incline, context.l10n.inclinePercent),
    };
    return WorkoutNumberField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label ?? defaultLabel,
        hintText: hint,
      ),
      focusNode: focus,
      step: step,
      integer:
          metric == WorkoutMetric.minutes || metric == WorkoutMetric.seconds,
      suffixIcon: suffixIcon,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textInputAction: action,
      validator: step == null ? null : requiredNumberValidator(context),
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
        child: field(
          context,
          WorkoutMetric.minutes,
          hint: minutesHint,
          focus: minutesFocus,
          onChanged: onChanged,
          onSubmitted: onMinutesSubmitted,
          action: TextInputAction.next,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: field(
          context,
          WorkoutMetric.seconds,
          hint: secondsHint,
          focus: secondsFocus,
          onChanged: onChanged,
          onSubmitted: onSecondsSubmitted,
          action: TextInputAction.next,
        ),
      ),
    ],
  );
}
