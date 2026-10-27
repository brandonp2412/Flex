import 'package:flex/constants.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

String formatSetSummary(
  BuildContext context, {
  required String unitCode,
  required bool cardio,
  required double weight,
  required double reps,
  required double distance,
  required double duration,
  int? incline,
  bool bodyWeight = false,
}) {
  final unit = displayMeasurementUnit(context.l10n, unitCode);
  final weightText = formatDisplayNumber(context, weight);
  if (bodyWeight) return '$weightText $unit';
  if (!cardio) {
    return '${formatDisplayNumber(context, reps)} × $weightText $unit';
  }
  final value = isWeightUnit(unitCode) ? weight : distance;
  final minutes = duration.floor();
  final seconds = ((duration * 60) % 60).floor().toString().padLeft(2, '0');
  final suffix = incline != null && incline > 0
      ? ' @ ${formatDisplayPercent(context, incline / 100, maxDigits: 0)}'
      : '';
  return '${formatDisplayNumber(context, value)} $unit / $minutes:$seconds$suffix';
}
