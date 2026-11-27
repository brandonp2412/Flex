import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/main.dart';
import 'package:flutter/material.dart';

class SettingToggle extends StatelessWidget {
  const SettingToggle({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.icon,
    required this.outlinedIcon,
    this.update,
    this.onChanged,
    this.subtitle,
  });

  final Widget title;
  final String description;
  final bool value;
  final IconData icon;
  final IconData outlinedIcon;
  final SettingsCompanion Function(bool)? update;
  final ValueChanged<bool>? onChanged;
  final Widget? subtitle;

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
        title: title,
        subtitle: subtitle,
        leading: Icon(value ? icon : outlinedIcon),
        onTap: () => change(!value),
        trailing: Switch(value: value, onChanged: change),
      ),
    );
  }
}
