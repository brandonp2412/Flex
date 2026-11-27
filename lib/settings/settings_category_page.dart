import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flex/settings/appearance_settings.dart';
import 'package:flex/settings/custom_timer_settings.dart';
import 'package:flex/settings/data_settings.dart';
import 'package:flex/settings/format_settings.dart';
import 'package:flex/settings/plan_settings.dart';
import 'package:flex/settings/settings_category.dart';
import 'package:flex/settings/settings_inputs.dart';
import 'package:flex/settings/timer_settings.dart';
import 'package:flex/settings/workout_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

export 'package:flex/settings/settings_category.dart';

List<Widget> settingsItems(
  BuildContext context,
  SettingsCategory category,
  Setting settings,
  SettingsInputs inputs, {
  String? search,
}) {
  final term = search ?? '';
  return switch (category) {
    SettingsCategory.appearance => getAppearanceSettings(
      context,
      term,
      settings,
    ),
    SettingsCategory.formats => getFormatSettings(context, term, settings),
    SettingsCategory.workouts =>
      search == null
          ? workoutSettingsSections(context, settings)
          : getWorkoutSettings(context, term, settings),
    SettingsCategory.plans => getPlanSettings(
      context,
      term,
      settings,
      inputs.maxSets,
      inputs.warmupSets,
    ),
    SettingsCategory.data => getDataSettings(term, settings, context),
    SettingsCategory.tabs => const [],
    SettingsCategory.timers =>
      inputs.player.enabled
          ? [
              ...getTimerSettings(
                term,
                settings,
                inputs.rest,
                inputs.player,
                context,
              ),
              if (search == null) const CustomTimerSettings(),
            ]
          : [
              if (search == null)
                ListTile(
                  title: Text(
                    context.l10n.timerSettings,
                    textAlign: TextAlign.start,
                  ),
                  subtitle: Text(
                    context.l10n.audioFeaturesUnavailable,
                    textAlign: TextAlign.start,
                  ),
                ),
            ],
  };
}

class SettingsCategoryPage extends StatefulWidget {
  const SettingsCategoryPage(this.category, {super.key});
  final SettingsCategory category;

  @override
  State<SettingsCategoryPage> createState() => _SettingsCategoryPageState();
}

class _SettingsCategoryPageState extends State<SettingsCategoryPage> {
  late final SettingsInputs _inputs;

  @override
  void initState() {
    super.initState();
    _inputs = SettingsInputs(context.read<Setting>());
  }

  @override
  void dispose() {
    _inputs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    appBar: AppBar(title: Text(widget.category.presentation(context).$2)),
    body: ResponsiveSettingsList(
      children: settingsItems(
        context,
        widget.category,
        context.watch<Setting>(),
        _inputs,
      ),
    ),
  );
}
