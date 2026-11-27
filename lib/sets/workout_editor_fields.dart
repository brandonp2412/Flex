import 'package:flex/l10n/l10n.dart';
import 'package:flex/constants.dart';
import 'package:flutter/material.dart';

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
