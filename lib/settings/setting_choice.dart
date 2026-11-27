import 'package:drift/drift.dart' hide Column;
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/main.dart';
import 'package:flutter/material.dart';

class SettingChoice<T extends Object> extends StatelessWidget {
  const SettingChoice({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.update,
  });
  final String label;
  final T value;
  final Map<T, String> choices;
  final SettingsCompanion Function(T) update;

  @override
  Widget build(BuildContext context) => Padding(
    padding: settingsPadding,
    child: DropdownButtonFormField<T>(
      decoration: InputDecoration(labelText: label),
      initialValue: value,
      items: [
        for (final entry in choices.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (value) => db.settings.update().write(update(value!)),
    ),
  );
}
