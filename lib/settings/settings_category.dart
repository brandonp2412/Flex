import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum SettingsCategory {
  appearance,
  data,
  formats,
  plans,
  tabs,
  timers,
  workouts;

  (IconData, String, String) presentation(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      workouts => (
        Icons.fitness_center_rounded,
        l10n.workouts,
        l10n.workoutsDescription,
      ),
      plans => (
        Icons.calendar_today_rounded,
        l10n.navPlans,
        l10n.plansSettingsDescription,
      ),
      timers => (Icons.timer_rounded, l10n.timers, l10n.timersDescription),
      appearance => (
        Icons.color_lens_rounded,
        l10n.appearance,
        l10n.appearanceDescription,
      ),
      formats => (
        Icons.format_bold_rounded,
        l10n.formats,
        l10n.formatsDescription,
      ),
      tabs => (Icons.tab_rounded, l10n.tabs, l10n.tabsDescription),
      data => (
        Icons.storage_rounded,
        l10n.dataManagement,
        l10n.dataManagementDescription,
      ),
    };
  }
}
