import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';
import 'package:flex/measurement_units.dart';
import 'package:flex/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Consistent padding for input fields (dropdowns, text fields) in settings screens.
const settingsPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 8);

const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String localizedWeekday(
  AppLocalizations l10n,
  String storedWeekday, {
  bool abbreviated = false,
}) {
  final index = weekdays.indexOf(storedWeekday);
  if (index < 0) return storedWeekday;
  final date = DateTime.utc(2024, 1, index + 1);
  return DateFormat(abbreviated ? 'EEE' : 'EEEE', l10n.localeName).format(date);
}

enum CardioMetric {
  pace,
  distance,
  duration,
  incline,
  inclineAdjustedPace,
  weight,
}

enum Period { day, week, month, year }

enum PlanTrailing { reorder, ratio, count, percent, none }

enum StrengthMetric {
  oneRepMax,
  volume,
  bestWeight,
  relativeStrength,
  bestReps,
}

enum GraphSort { dateDesc, dateAsc, name }

final defaultSettings = SettingsCompanion.insert(
  themeMode: ThemeMode.system.toString(),
  planTrailing: PlanTrailing.reorder.toString(),
  longDateFormat: 'timeago',
  shortDateFormat: 'd/M/yy',
  timerDuration: const Duration(minutes: 3, seconds: 30).inMilliseconds,
  maxSets: 3,
  warmupSets: const Value(0),
  vibrate: true,
  restTimers: false,
  showUnits: false,
  alarmSound: '',
  cardioUnit: 'last-entry',
  curveLines: true,
  durationEstimation: const Value(false),
  explainedPermissions: false,
  groupHistory: false,
  notifications: const Value(false),
  showBodyWeight: const Value(false),
  showImages: const Value(false),
  showGlobalProgress: const Value(false),
  strengthUnit: 'last-entry',
  systemColors: false,
  showCategories: const Value(false),
  keepScreenOn: const Value(false),
  showNotes: const Value(false),
);

Map<String, String> strengthUnitLabels(AppLocalizations l10n) => {
  'kg': l10n.kilogramsUnit,
  'lb': l10n.poundsUnit,
  'stone': l10n.stoneUnit,
};

Map<String, String> cardioUnitLabels(
  AppLocalizations l10n, {
  bool distanceOnly = false,
}) => {
  'km': l10n.kilometersUnit,
  'mi': l10n.milesUnit,
  'm': l10n.metersUnit,
  if (!distanceOnly) 'kcal': l10n.kilocaloriesUnit,
};

List<DropdownMenuItem<String>> _unitItems(Map<String, String> labels) => [
  for (final entry in labels.entries)
    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
];

List<DropdownMenuItem<String>> strengthUnitMenuItems(AppLocalizations l10n) =>
    _unitItems(strengthUnitLabels(l10n));
List<DropdownMenuItem<String>> cardioDistanceUnitMenuItems(
  AppLocalizations l10n,
) => _unitItems(cardioUnitLabels(l10n, distanceOnly: true));
List<DropdownMenuItem<String>> cardioUnitMenuItems(AppLocalizations l10n) =>
    _unitItems(cardioUnitLabels(l10n));

String displayMeasurementUnit(AppLocalizations l10n, String unit) =>
    unit == 'stone' ? l10n.stoneUnitShort : unit;

List<String> positiveReinforcementMessages(AppLocalizations l10n) => [
  l10n.recordEncouragement01,
  l10n.recordEncouragement02,
  l10n.recordEncouragement03,
  l10n.recordEncouragement04,
  l10n.recordEncouragement05,
  l10n.recordEncouragement06,
  l10n.recordEncouragement07,
  l10n.recordEncouragement08,
  l10n.recordEncouragement09,
  l10n.recordEncouragement10,
  l10n.recordEncouragement11,
  l10n.recordEncouragement12,
  l10n.recordEncouragement13,
  l10n.recordEncouragement14,
  l10n.recordEncouragement15,
  l10n.recordEncouragement16,
  l10n.recordEncouragement17,
  l10n.recordEncouragement18,
  l10n.recordEncouragement19,
  l10n.recordEncouragement20,
  l10n.recordEncouragement21,
  l10n.recordEncouragement22,
  l10n.recordEncouragement23,
  l10n.recordEncouragement24,
  l10n.recordEncouragement25,
  l10n.recordEncouragement26,
  l10n.recordEncouragement27,
  l10n.recordEncouragement28,
  l10n.recordEncouragement29,
];

bool isWeightUnit(String? unit) => weightUnitFactors.containsKey(unit);
