import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/graph/cardio_data.dart';
import 'package:flex/graph/edit_graph_page.dart';
import 'package:flex/graph/exercise_graph_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CardioPage extends StatefulWidget {
  final String initialName;
  final String initialUnit;
  final List<CardioData> initialData;
  final TabController tabCtrl;

  const CardioPage({
    super.key,
    required this.initialName,
    required this.initialUnit,
    required this.initialData,
    required this.tabCtrl,
  });

  @override
  createState() => _CardioPageState();
}

class _CardioPageState extends ExerciseGraphState<CardioPage, CardioMetric> {
  late List<CardioData> _data;

  @override
  TabController get tabController => widget.tabCtrl;

  @override
  List<DropdownMenuItem<String>> get optionsUnits {
    if (!context.read<Setting>().showUnits) return const [];
    return switch (metric) {
      CardioMetric.weight => strengthUnitMenuItems(context.l10n),
      CardioMetric.distance => cardioDistanceUnitMenuItems(context.l10n),
      _ => const [],
    };
  }

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    initialize(widget.initialName, widget.initialUnit);
  }

  @override
  CardioMetric defaultMetric(Setting settings) => isWeightUnit(targetUnit)
      ? CardioMetric.weight
      : CardioMetric.values.firstWhere(
          (m) => m.name == settings.defaultGraphMetric,
          orElse: () => CardioMetric.pace,
        );

  @override
  CardioMetric storedMetric(List<String> stored) {
    final allowed = isWeightUnit(targetUnit)
        ? {CardioMetric.weight, CardioMetric.duration, CardioMetric.incline}
        : {
            CardioMetric.pace,
            CardioMetric.inclineAdjustedPace,
            CardioMetric.duration,
            CardioMetric.distance,
            CardioMetric.incline,
          };
    return CardioMetric.values.firstWhere(
      (m) => stored.contains(m.name) && allowed.contains(m),
      orElse: () =>
          isWeightUnit(targetUnit) ? CardioMetric.weight : CardioMetric.pace,
    );
  }

  @override
  DateTime? pointDate(int index) =>
      index < 0 || index >= _data.length ? null : _data[index].created;

  @override
  List<({DateTime created, double value})> get chartRows => [
    for (final row in _data)
      (created: row.created, value: double.parse(row.value.toStringAsFixed(1))),
  ];

  @override
  String tooltip(int index, String format) =>
      tooltipText(metric, _data[index], format);

  String tooltipText(
    CardioMetric selectedMetric,
    CardioData row,
    String format,
  ) {
    String text = formatDisplayNumber(context, row.value, minDigits: 2);
    final created = formatDisplayDate(context, row.created, format);
    switch (selectedMetric) {
      case CardioMetric.pace:
        text =
            "${formatDisplayNumber(context, row.value)} ${displayMeasurementUnit(context.l10n, row.unit)} / ${context.l10n.minutesShort}";
        break;
      case CardioMetric.duration:
        final minutes = row.value.floor();
        final seconds = ((row.value * 60) % 60).floor().toString().padLeft(
          2,
          '0',
        );
        text = "$minutes:$seconds";
        break;
      case CardioMetric.distance:
        text += " ${displayMeasurementUnit(context.l10n, row.unit)}";
        break;
      case CardioMetric.incline:
        text = formatDisplayPercent(context, row.value / 100);
        break;
      case CardioMetric.inclineAdjustedPace:
        break;
      case CardioMetric.weight:
        text += " ${displayMeasurementUnit(context.l10n, row.unit)}";
        break;
    }
    return "$text\n$created";
  }

  @override
  List<(CardioMetric, String)> get metricOptions => isWeightUnit(targetUnit)
      ? <(CardioMetric, String)>[
          (CardioMetric.weight, context.l10n.weightLabel),
          (CardioMetric.duration, context.l10n.durationLabel),
          (CardioMetric.incline, context.l10n.inclineLabel),
        ]
      : <(CardioMetric, String)>[
          (CardioMetric.pace, context.l10n.paceDistanceTime),
          (CardioMetric.inclineAdjustedPace, context.l10n.adjustedPace),
          (CardioMetric.duration, context.l10n.durationLabel),
          (CardioMetric.distance, context.l10n.distanceLabel),
          (CardioMetric.incline, context.l10n.inclineLabel),
        ];

  @override
  Future<void> editGraph() async {
    final newName = await Navigator.of(context).push<String>(
      FlexPageRoute(builder: (context) => EditGraphPage(name: exerciseName)),
    );
    if (mounted && newName != null) {
      final updated = await getExerciseByName(db, newName);
      if (!mounted) return;
      setState(() {
        exerciseName = newName;
        if (updated != null) targetUnit = updated.displayUnit;
        final supportsWeight = isWeightUnit(targetUnit);
        final allowed = supportsWeight
            ? {CardioMetric.weight, CardioMetric.duration, CardioMetric.incline}
            : {
                CardioMetric.pace,
                CardioMetric.inclineAdjustedPace,
                CardioMetric.duration,
                CardioMetric.distance,
                CardioMetric.incline,
              };
        if (!allowed.contains(metric)) {
          metric = supportsWeight ? CardioMetric.weight : CardioMetric.pace;
        }
      });
      setData();
    }
  }

  @override
  bool get cardio => true;

  @override
  Future<void> setData() async {
    if (!mounted) return;
    final request = ++dataRequest;
    final selected = metric;
    final rows = await getCardioData(
      end: end,
      period: period,
      metric: selected,
      name: exerciseName,
      start: start,
      target: targetUnit,
      limit: limit,
    );
    if (!mounted || request != dataRequest) return;
    setState(() => _data = rows);
  }
}
