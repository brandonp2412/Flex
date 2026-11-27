import 'package:flex/settings/setting_toggle.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/category_management_page.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

({List<Widget> tracking, List<Widget> history, List<Widget> graphs})
getWorkoutSettingGroups(BuildContext context, String term, Setting settings) {
  final l10n = context.l10n;
  final normalizedTerm = term.trim().toLowerCase();
  bool matches(Iterable<String> values) =>
      values.join(' ').toLowerCase().contains(normalizedTerm);
  return (
    history: [
      if (matches([l10n.groupHistory, l10n.groupHistoryDescription]))
        SettingToggle(
          title: Text(l10n.groupHistory),
          subtitle: Text(l10n.groupHistoryDescription),
          description: l10n.groupHistoryDescription,
          value: settings.groupHistory,
          icon: Icons.view_agenda,
          outlinedIcon: Icons.view_agenda_outlined,
          update: (value) => SettingsCompanion(groupHistory: Value(value)),
        ),
      if (matches([l10n.showUnits, l10n.showUnitsDescription]))
        SettingToggle(
          title: Text(l10n.showUnits),
          subtitle: Text(l10n.showUnitsDescription),
          description: l10n.showUnitsDescription,
          value: settings.showUnits,
          icon: Icons.scale,
          outlinedIcon: Icons.scale_outlined,
          update: (value) => SettingsCompanion(showUnits: Value(value)),
        ),
    ],
    tracking: [
      if (matches([l10n.showBodyWeight, l10n.showBodyWeightDescription]))
        SettingToggle(
          title: Text(l10n.showBodyWeight),
          subtitle: Text(l10n.showBodyWeightDescription),
          description: l10n.showBodyWeightDescription,
          value: settings.showBodyWeight,
          icon: Icons.monitor_weight,
          outlinedIcon: Icons.monitor_weight_outlined,
          update: (value) => SettingsCompanion(showBodyWeight: Value(value)),
        ),
      if (matches([l10n.showCategories, l10n.showCategoriesDescription]))
        SettingToggle(
          title: Text(l10n.showCategories),
          subtitle: Text(l10n.showCategoriesDescription),
          description: l10n.showCategoriesDescription,
          value: settings.showCategories,
          icon: Icons.category,
          outlinedIcon: Icons.category_outlined,
          update: (value) => SettingsCompanion(showCategories: Value(value)),
        ),
      if (matches([l10n.manageCategories, l10n.manageCategoriesDescription]))
        ListTile(
          leading: const Icon(Icons.category),
          title: Text(l10n.manageCategories),
          subtitle: Text(l10n.manageCategoriesDescription),
          onTap: () => Navigator.of(
            context,
          ).push(FlexPageRoute(builder: (_) => const CategoryManagementPage())),
        ),
      if (matches([l10n.showNotes, l10n.showNotesDescription]))
        SettingToggle(
          title: Text(l10n.showNotes),
          subtitle: Text(l10n.showNotesDescription),
          description: l10n.showNotesDescription,
          value: settings.showNotes,
          icon: Icons.note_alt,
          outlinedIcon: Icons.note_alt_outlined,
          update: (value) => SettingsCompanion(showNotes: Value(value)),
        ),
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
                messengerKey.currentState!.showSnackBar(
                  SnackBar(
                    content: Text(l10n.positiveMessagesEnabled),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    duration: const Duration(seconds: 4),
                    persist: false,
                  ),
                );
            },
            trailing: Switch(
              value: settings.notifications,
              onChanged: (value) => db.settings.update().write(
                SettingsCompanion(notifications: Value(value)),
              ),
            ),
          ),
        ),
      if (matches([
        l10n.durationEstimation,
        l10n.durationEstimationDescription,
      ]))
        SettingToggle(
          title: Text(l10n.durationEstimation),
          subtitle: Text(l10n.durationEstimationDescription),
          description: l10n.durationEstimationDescription,
          value: settings.durationEstimation,
          icon: Icons.schedule,
          outlinedIcon: Icons.schedule_outlined,
          update: (value) =>
              SettingsCompanion(durationEstimation: Value(value)),
        ),
    ],
    graphs: [
      if (matches([
        l10n.showGraphXAxisToggle,
        l10n.showGraphXAxisToggleDescription,
      ]))
        SettingToggle(
          title: Text(l10n.showGraphXAxisToggle),
          subtitle: Text(l10n.showGraphXAxisToggleDescription),
          description: l10n.showGraphXAxisToggleDescription,
          value: settings.showGraphXAxis,
          icon: Icons.show_chart,
          outlinedIcon: Icons.show_chart_outlined,
          update: (value) => SettingsCompanion(showGraphXAxis: Value(value)),
        ),
      if (matches([l10n.showGraphLimit, l10n.showGraphLimitDescription]))
        SettingToggle(
          title: Text(l10n.showGraphLimit),
          subtitle: Text(l10n.showGraphLimitDescription),
          description: l10n.showGraphLimitDescription,
          value: settings.showGraphLimit,
          icon: Icons.tune,
          outlinedIcon: Icons.tune_outlined,
          update: (value) => SettingsCompanion(showGraphLimit: Value(value)),
        ),
      if (matches([
        l10n.defaultGraphMetric,
        l10n.bestWeight,
        l10n.bestReps,
        l10n.oneRepMax,
        '1RM',
        l10n.volume,
        l10n.paceCardio,
        l10n.distanceCardio,
      ]))
        Padding(
          padding: settingsPadding,
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: l10n.defaultGraphMetric),
            initialValue: settings.defaultGraphMetric,
            items: [
              DropdownMenuItem(
                value: 'bestWeight',
                child: Text(l10n.bestWeight),
              ),
              DropdownMenuItem(value: 'bestReps', child: Text(l10n.bestReps)),
              DropdownMenuItem(value: 'oneRepMax', child: Text(l10n.oneRepMax)),
              DropdownMenuItem(value: 'volume', child: Text(l10n.volume)),
              DropdownMenuItem(value: 'pace', child: Text(l10n.paceCardio)),
              DropdownMenuItem(
                value: 'distance',
                child: Text(l10n.distanceCardio),
              ),
            ],
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(defaultGraphMetric: Value(value!)),
            ),
          ),
        ),
      if (matches([
        l10n.defaultGraphPeriod,
        l10n.daily,
        l10n.weekly,
        l10n.monthly,
        l10n.yearly,
      ]))
        Padding(
          padding: settingsPadding,
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: l10n.defaultGraphPeriod),
            initialValue: settings.defaultGraphPeriod,
            items: [
              DropdownMenuItem(value: 'day', child: Text(l10n.daily)),
              DropdownMenuItem(value: 'week', child: Text(l10n.weekly)),
              DropdownMenuItem(value: 'month', child: Text(l10n.monthly)),
              DropdownMenuItem(value: 'year', child: Text(l10n.yearly)),
            ],
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(defaultGraphPeriod: Value(value!)),
            ),
          ),
        ),
      if (matches([
        l10n.defaultGraphLimit,
        '10',
        '20',
        '30',
        '50',
        '100',
        '200',
      ]))
        Padding(
          padding: settingsPadding,
          child: DropdownButtonFormField<int>(
            decoration: InputDecoration(labelText: l10n.defaultGraphLimit),
            initialValue: settings.defaultGraphLimit,
            items: const [
              DropdownMenuItem(value: 10, child: Text("10")),
              DropdownMenuItem(value: 20, child: Text("20")),
              DropdownMenuItem(value: 30, child: Text("30")),
              DropdownMenuItem(value: 50, child: Text("50")),
              DropdownMenuItem(value: 100, child: Text("100")),
              DropdownMenuItem(value: 200, child: Text("200")),
            ],
            onChanged: (value) => db.settings.update().write(
              SettingsCompanion(defaultGraphLimit: Value(value!)),
            ),
          ),
        ),
      if (matches([
        l10n.defaultTimeBasedXAxis,
        l10n.defaultTimeBasedXAxisDescription,
      ]))
        SettingToggle(
          title: Text(l10n.defaultTimeBasedXAxis),
          subtitle: Text(l10n.defaultTimeBasedXAxisDescription),
          description: l10n.defaultTimeBasedXAxisDescription,
          value: settings.defaultGraphTimeBasedXAxis,
          icon: Icons.timeline,
          outlinedIcon: Icons.timeline_outlined,
          update: (value) =>
              SettingsCompanion(defaultGraphTimeBasedXAxis: Value(value)),
        ),
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

class WorkoutSettings extends StatefulWidget {
  const WorkoutSettings({super.key});

  @override
  State<WorkoutSettings> createState() => _WorkoutSettingsState();
}

class _WorkoutSettingsState extends State<WorkoutSettings> {
  late var _settings = context.read<Setting>();

  @override
  Widget build(BuildContext context) {
    _settings = context.watch<Setting>();
    final settings = getWorkoutSettingGroups(context, '', _settings);

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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(context.l10n.workouts)),
      body: ResponsiveSettingsList(
        children: [
          section(null, settings.tracking),
          section(context.l10n.navHistory, settings.history),
          section(context.l10n.navGraphs, settings.graphs, collapsed: true),
        ],
      ),
    );
  }
}
