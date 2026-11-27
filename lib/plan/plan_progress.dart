import 'package:flex/constants.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

String planProgressLabel(
  BuildContext context,
  PlanTrailing trailing,
  int count,
  int max,
) {
  String number(int value) => formatDisplayNumber(context, value, maxDigits: 0);
  return switch (trailing) {
    PlanTrailing.count => number(count),
    PlanTrailing.percent => formatDisplayPercent(context, count / max),
    _ => "${number(count)} / ${number(max)}",
  };
}
