import 'package:flex/settings/setting_toggle.dart';
import 'package:flex/settings/setting_choice.dart';
import 'package:drift/drift.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

final List<String> long = [
  'timeago',
  'dd/MM/yy',
  'dd/MM/yy h:mm a',
  'dd/MM/yy H:mm',
  'dd.MM.yyyy H:mm',
  'EEE h:mm a',
  'yyyy-MM-dd',
  'yyyy-MM-dd h:mm a',
  'yyyy-MM-dd H:mm',
  'yyyy.MM.dd',
  'yyyy.MM.dd h:mm a',
  'yyyy.MM.dd H:mm',
  'MMM d (EEE) h:mm a',
  'EEE, dd.MM.yyyy H:mm',
];

final List<String> short = [
  'd/M/yy',
  'M/d/yy',
  'd-M-yy',
  'M-d-yy',
  'd.M.yy',
  'M.d.yy',
  'dd.MM.yy',
];

List<Widget> getFormatSettings(
  BuildContext context,
  String term,
  Setting settings,
) {
  final l10n = context.l10n;
  bool matches(Iterable<String> values) => settingMatches(term, values);
  final now = DateTime.now();
  final currentLong = settings.longDateFormat == 'timeago'
      ? formatRelativeTime(context, now)
      : formatDisplayDate(context, now, settings.longDateFormat);
  return [
    if (matches([
      l10n.strengthUnit,
      l10n.lastEntry,
      l10n.kilogramsUnit,
      l10n.poundsUnit,
      l10n.stoneUnit,
    ]))
      SettingChoice<String>(
        label: l10n.strengthUnit,
        value: settings.strengthUnit,
        choices: {'last-entry': l10n.lastEntry, ...strengthUnitLabels(l10n)},
        isExpanded: true,
        update: (value) => SettingsCompanion(strengthUnit: Value(value)),
      ),
    if (matches([
      l10n.cardioUnit,
      l10n.lastEntry,
      l10n.kilometersUnit,
      l10n.milesUnit,
      l10n.metersUnit,
      l10n.kilocaloriesUnit,
    ]))
      SettingChoice<String>(
        label: l10n.cardioUnit,
        value: settings.cardioUnit,
        choices: {'last-entry': l10n.lastEntry, ...cardioUnitLabels(l10n)},
        isExpanded: true,
        update: (value) => SettingsCompanion(cardioUnit: Value(value)),
      ),
    if (matches([
      l10n.longDateFormat(''),
      l10n.longDateFormatDescription,
      ...long,
    ]))
      SettingChoice<String>(
        label: l10n.longDateFormat(currentLong),
        value: settings.longDateFormat,
        choices: {for (final value in long) value: value},
        description: l10n.longDateFormatDescription,
        isExpanded: true,
        menuMaxHeight: 300,
        update: (value) => SettingsCompanion(longDateFormat: Value(value)),
      ),
    if (matches([
      l10n.shortDateFormat(''),
      l10n.shortDateFormatDescription,
      ...short,
    ]))
      SettingChoice<String>(
        label: l10n.shortDateFormat(
          formatDisplayDate(context, now, settings.shortDateFormat),
        ),
        value: settings.shortDateFormat,
        choices: {for (final value in short) value: value},
        description: l10n.shortDateFormatDescription,
        isExpanded: true,
        update: (value) => SettingsCompanion(shortDateFormat: Value(value)),
      ),
  ];
}
