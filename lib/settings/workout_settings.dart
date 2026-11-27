import 'package:flex/app_message.dart';
import 'package:flex/settings/setting_choice.dart';
import 'package:flex/settings/setting_toggle.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/settings/category_management_page.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flutter/material.dart';

({List<Widget> tracking, List<Widget> history, List<Widget> graphs})
getWorkoutSettingGroups(BuildContext context, String term, Setting settings) {
  final l10n = context.l10n;
  bool matches(Iterable<String> values) => settingMatches(term, values);
  return (
    history: [
      ...matchingToggles(term, [
        SettingToggle(
          label: l10n.groupHistory,
          description: l10n.groupHistoryDescription,
          showDescription: true,
          value: settings.groupHistory,
          icon: Icons.view_agenda,
          outlinedIcon: Icons.view_agenda_outlined,
          update: (value) => SettingsCompanion(groupHistory: Value(value)),
        ),
        SettingToggle(
          label: l10n.showUnits,
          description: l10n.showUnitsDescription,
          showDescription: true,
          value: settings.showUnits,
          icon: Icons.scale,
          outlinedIcon: Icons.scale_outlined,
          update: (value) => SettingsCompanion(showUnits: Value(value)),
        ),
      ]),
    ],
    tracking: [
      ...matchingToggles(term, [
        SettingToggle(
          label: l10n.showBodyWeight,
          description: l10n.showBodyWeightDescription,
          showDescription: true,
          value: settings.showBodyWeight,
          icon: Icons.monitor_weight,
          outlinedIcon: Icons.monitor_weight_outlined,
          update: (value) => SettingsCompanion(showBodyWeight: Value(value)),
        ),
        SettingToggle(
          label: l10n.showCategories,
          description: l10n.showCategoriesDescription,
          showDescription: true,
          value: settings.showCategories,
          icon: Icons.category,
          outlinedIcon: Icons.category_outlined,
          update: (value) => SettingsCompanion(showCategories: Value(value)),
        ),
      ]),
      if (matches([l10n.manageCategories, l10n.manageCategoriesDescription]))
        ListTile(
          leading: const Icon(Icons.category),
          title: Text(l10n.manageCategories),
          subtitle: Text(l10n.manageCategoriesDescription),
          onTap: () => Navigator.of(
            context,
          ).push(FlexPageRoute(builder: (_) => const CategoryManagementPage())),
        ),
      ...matchingToggles(term, [
        SettingToggle(
          label: l10n.showNotes,
          description: l10n.showNotesDescription,
          showDescription: true,
          value: settings.showNotes,
          icon: Icons.note_alt,
          outlinedIcon: Icons.note_alt_outlined,
          update: (value) => SettingsCompanion(showNotes: Value(value)),
        ),
      ]),
      if (matches([
        l10n.positiveReinforcement,
        l10n.positiveNotificationsDescription,
      ]))
        Tooltip(
          message: l10n.positiveNotificationsDescription,
          child: ListTile(
            title: Text(l10n.positiveReinforcement),
            subtitle: Text(l10n.positiveNotificationsDescription),
            leading: const Icon(Icons.celebration_outlined),
            onTap: () {
              db.settings.update().write(
                SettingsCompanion(
                  notifications: Value(!settings.notifications),
                ),
              );
              if (!settings.notifications)
                showAppMessage(l10n.positiveMessagesEnabled);
            },
            trailing: Switch(
              value: settings.notifications,
              onChanged: (value) => db.settings.update().write(
                SettingsCompanion(notifications: Value(value)),
              ),
            ),
          ),
        ),
      ...matchingToggles(term, [
        SettingToggle(
          label: l10n.durationEstimation,
          description: l10n.durationEstimationDescription,
          showDescription: true,
          value: settings.durationEstimation,
          icon: Icons.schedule,
          outlinedIcon: Icons.schedule_outlined,
          update: (value) =>
              SettingsCompanion(durationEstimation: Value(value)),
        ),
      ]),
    ],
    graphs: [
      ...matchingToggles(term, [
        SettingToggle(
          label: l10n.showGraphXAxisToggle,
          description: l10n.showGraphXAxisToggleDescription,
          showDescription: true,
          value: settings.showGraphXAxis,
          icon: Icons.show_chart,
          outlinedIcon: Icons.show_chart_outlined,
          update: (value) => SettingsCompanion(showGraphXAxis: Value(value)),
        ),
        SettingToggle(
          label: l10n.showGraphLimit,
          description: l10n.showGraphLimitDescription,
          showDescription: true,
          value: settings.showGraphLimit,
          icon: Icons.tune,
          outlinedIcon: Icons.tune_outlined,
          update: (value) => SettingsCompanion(showGraphLimit: Value(value)),
        ),
      ]),
      ...matchingChoices(term, [
        SettingChoice<String>(
          label: l10n.defaultGraphMetric,
          searchTerms: ['1RM'],
          value: settings.defaultGraphMetric,
          choices: {
            'bestWeight': l10n.bestWeight,
            'bestReps': l10n.bestReps,
            'oneRepMax': l10n.oneRepMax,
            'volume': l10n.volume,
            'pace': l10n.paceCardio,
            'distance': l10n.distanceCardio,
          },
          update: (value) =>
              SettingsCompanion(defaultGraphMetric: Value(value)),
        ),
        SettingChoice<String>(
          label: l10n.defaultGraphPeriod,
          value: settings.defaultGraphPeriod,
          choices: {
            'day': l10n.daily,
            'week': l10n.weekly,
            'month': l10n.monthly,
            'year': l10n.yearly,
          },
          update: (value) =>
              SettingsCompanion(defaultGraphPeriod: Value(value)),
        ),
        SettingChoice<int>(
          label: l10n.defaultGraphLimit,
          value: settings.defaultGraphLimit,
          choices: {
            for (final n in [10, 20, 30, 50, 100, 200]) n: n.toString(),
          },
          update: (value) => SettingsCompanion(defaultGraphLimit: Value(value)),
        ),
      ]),
      ...matchingToggles(term, [
        SettingToggle(
          label: l10n.defaultTimeBasedXAxis,
          description: l10n.defaultTimeBasedXAxisDescription,
          showDescription: true,
          value: settings.defaultGraphTimeBasedXAxis,
          icon: Icons.timeline,
          outlinedIcon: Icons.timeline_outlined,
          update: (value) =>
              SettingsCompanion(defaultGraphTimeBasedXAxis: Value(value)),
        ),
      ]),
    ],
  );
}

List<Widget> getWorkoutSettings(
  BuildContext context,
  String term,
  Setting settings,
) {
  final groups = getWorkoutSettingGroups(context, term, settings);
  return [...groups.tracking, ...groups.history, ...groups.graphs];
}

List<Widget> workoutSettingsSections(BuildContext context, Setting value) {
  final settings = getWorkoutSettingGroups(context, '', value);
  Widget section(
    String? title,
    List<Widget> children, {
    bool collapsed = false,
  }) {
    final content = collapsed
        ? ExpansionTile(
            title: Text(title!),
            initiallyExpanded: false,
            children: children,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ...children,
            ],
          );

    return content;
  }

  return [
    section(null, settings.tracking),
    section(context.l10n.navHistory, settings.history),
    section(context.l10n.navGraphs, settings.graphs, collapsed: true),
  ];
}
