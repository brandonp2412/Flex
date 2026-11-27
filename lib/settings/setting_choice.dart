import 'package:flex/settings/setting_toggle.dart';
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
    this.description,
    this.isExpanded = false,
    this.menuMaxHeight,
    this.searchTerms = const [],
  });
  final String label;
  final T value;
  final Map<T, String> choices;
  final SettingsCompanion Function(T) update;
  final String? description;
  final bool isExpanded;
  final double? menuMaxHeight;
  final List<String> searchTerms;

  bool matches(String term) => settingMatches(term, [
    label,
    ?description,
    ...choices.values,
    ...searchTerms,
  ]);

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      decoration: InputDecoration(labelText: label),
      initialValue: value,
      isExpanded: isExpanded,
      menuMaxHeight: menuMaxHeight,
      items: [
        for (final entry in choices.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (value) => db.settings.update().write(update(value!)),
    );
    return Padding(
      padding: settingsPadding,
      child: description == null
          ? field
          : Tooltip(message: description!, child: field),
    );
  }
}

List<Widget> matchingChoices(String term, List<SettingChoice> choices) =>
    choices.where((choice) => choice.matches(term)).toList();
