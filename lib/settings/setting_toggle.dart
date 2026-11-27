import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/main.dart';
import 'package:flutter/material.dart';

class SettingToggle extends StatelessWidget {
  const SettingToggle({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.icon,
    required this.outlinedIcon,
    this.update,
    this.onChanged,
    this.showDescription = false,
  });

  final String label;
  final String description;
  final bool value;
  final IconData icon;
  final IconData outlinedIcon;
  final SettingsCompanion Function(bool)? update;
  final ValueChanged<bool>? onChanged;
  final bool showDescription;

  bool matches(String term) => settingMatches(term, [label, description]);

  @override
  Widget build(BuildContext context) {
    void change(bool next) {
      if (onChanged != null) {
        onChanged!(next);
      } else {
        db.settings.update().write(update!(next));
      }
    }

    return Tooltip(
      message: description,
      child: ListTile(
        title: Text(label, textAlign: TextAlign.start),
        subtitle: showDescription ? Text(description) : null,
        leading: Icon(value ? icon : outlinedIcon),
        onTap: () => change(!value),
        trailing: Switch(value: value, onChanged: change),
      ),
    );
  }
}

bool settingMatches(String term, Iterable<String> values) =>
    values.join(' ').toLowerCase().contains(term.trim().toLowerCase());

List<Widget> matchingToggles(String term, List<SettingToggle> toggles) =>
    toggles.where((toggle) => toggle.matches(term)).toList();
