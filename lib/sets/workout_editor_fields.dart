import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<DropdownMenuItem<String>> workoutUnitItems(BuildContext context) => [
  ...strengthUnitMenuItems(context.l10n),
  ...cardioUnitMenuItems(context.l10n),
];

Future<DateTime?> pickWorkoutDateTime(
  BuildContext context,
  DateTime? initial,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Widget exerciseKindSelector(
  BuildContext context,
  bool? cardio,
  ValueChanged<bool?> onChanged, {
  bool allowEmpty = false,
}) => SizedBox(
  width: 20,
  child: SegmentedButton<bool>(
    key: const Key('exercise-kind-selector'),
    showSelectedIcon: false,
    emptySelectionAllowed: allowEmpty,
    segments: [
      ButtonSegment(
        value: false,
        icon: const Icon(Icons.fitness_center),
        label: Text(context.l10n.strength),
      ),
      ButtonSegment(
        value: true,
        icon: const Icon(Icons.directions_run),
        label: Text(context.l10n.cardio),
      ),
    ],
    selected: cardio == null ? const {} : {cardio},
    onSelectionChanged: (selection) => onChanged(selection.firstOrNull),
  ),
);

Widget workoutDateField(
  BuildContext context,
  DateTime? created,
  VoidCallback onTap, {
  String? hint,
  bool compact = false,
}) => Selector<Setting, String>(
  selector: (_, settings) => settings.longDateFormat,
  builder: (context, format, child) => ListTile(
    contentPadding: compact ? EdgeInsets.zero : null,
    title: Text(context.l10n.createdDate),
    subtitle: Text(
      created == null
          ? hint ?? ''
          : formatWorkoutDate(context, created, format),
    ),
    trailing: const Icon(Icons.calendar_today),
    onTap: onTap,
  ),
);

String formatWorkoutDate(BuildContext context, DateTime date, String format) =>
    format == 'timeago'
    ? formatRelativeTime(context, date)
    : formatDisplayDate(context, date, format);
