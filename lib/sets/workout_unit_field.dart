import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/sets/workout_editor_fields.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutUnitField extends StatelessWidget {
  const WorkoutUnitField({
    super.key,
    required this.unit,
    required this.onChanged,
    this.inWorkout = false,
  });
  final String? unit;
  final ValueChanged<String> onChanged;
  final bool inWorkout;

  @override
  Widget build(BuildContext context) => Selector<Setting, bool>(
    selector: (context, settings) => settings.showUnits,
    builder: (context, showUnits, child) {
      final field = DropdownButtonFormField<String>(
        key: inWorkout ? ValueKey(unit) : null,
        isExpanded: inWorkout,
        decoration: InputDecoration(labelText: context.l10n.unitLabel),
        initialValue: unit,
        items: workoutUnitItems(context),
        onChanged: (value) => onChanged(value!),
      );
      return Visibility(
        visible: showUnits,
        child: inWorkout
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [const SizedBox(height: 8), field],
              )
            : field,
      );
    },
  );
}
