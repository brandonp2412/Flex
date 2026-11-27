import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/graph/edit_graph_page.dart';
import 'package:flex/graph/exercise_graph_state.dart';
import 'package:flex/graph/strength_data.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StrengthPage extends StatefulWidget {
  final String initialName;
  final String initialUnit;
  final List<StrengthData> initialData;
  final TabController tabCtrl;
  final bool bodyWeight;

  const StrengthPage({
    super.key,
    required this.initialName,
    required this.initialUnit,
    required this.initialData,
    required this.tabCtrl,
    this.bodyWeight = false,
  });

  @override
  createState() => _StrengthPageState();
}

class _StrengthPageState
    extends ExerciseGraphState<StrengthPage, StrengthMetric> {
  late List<StrengthData> _data;

  @override
  TabController get tabController => widget.tabCtrl;

  @override
  bool get bodyWeight => widget.bodyWeight;

  @override
  List<DropdownMenuItem<String>> get optionsUnits =>
      context.read<Setting>().showUnits
      ? strengthUnitMenuItems(context.l10n)
      : const [];

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    initialize(widget.initialName, widget.initialUnit);
  }

  @override
  StrengthMetric defaultMetric(Setting settings) =>
      StrengthMetric.values.firstWhere(
        (m) =>
            m.name == settings.defaultGraphMetric &&
            (settings.showBodyWeight || m != StrengthMetric.relativeStrength),
        orElse: () => StrengthMetric.bestWeight,
      );

  @override
  StrengthMetric storedMetric(List<String> stored) {
    final showBodyWeight = context.read<Setting>().showBodyWeight;
    return StrengthMetric.values.firstWhere(
      (m) =>
          stored.contains(m.name) &&
          (showBodyWeight || m != StrengthMetric.relativeStrength),
      orElse: () => StrengthMetric.bestWeight,
    );
  }

  @override
  DateTime? pointDate(int index) =>
      index < 0 || index >= _data.length ? null : _data[index].created;

  @override
  List<({DateTime created, double value})> get chartRows => [
    for (final row in _data) (created: row.created, value: row.value),
  ];

  @override
  String tooltip(int index, String format) =>
      tooltipText(metric, _data[index], format);

  @override
  List<(StrengthMetric, String)> get metricOptions =>
      <(StrengthMetric, String)>[
        (StrengthMetric.bestWeight, context.l10n.bestWeight),
        (StrengthMetric.bestReps, context.l10n.bestReps),
        (StrengthMetric.oneRepMax, context.l10n.oneRepMax),
        (StrengthMetric.volume, context.l10n.volume),
        if (context.select<Setting, bool>(
          (settings) => settings.showBodyWeight,
        ))
          (StrengthMetric.relativeStrength, context.l10n.relativeStrength),
      ];

  @override
  Future<void> editGraph() async {
    String? newName = await Navigator.of(context).push(
      FlexPageRoute(builder: (context) => EditGraphPage(name: exerciseName)),
    );
    if (mounted && newName != null) {
      setState(() {
        exerciseName = newName;
      });
    }
  }

  @override
  bool get showNotes =>
      context.select<Setting, bool>((settings) => settings.showNotes);

  @override
  Future<void> setData() async {
    if (!mounted) return;
    final request = ++dataRequest;
    final selected = metric;
    final rows = widget.bodyWeight
        ? await getBodyWeightData(
            target: targetUnit,
            period: period,
            start: start,
            end: end,
            limit: limit,
          )
        : await getStrengthData(
            target: targetUnit,
            name: exerciseName,
            metric: selected,
            period: period,
            start: start,
            end: end,
            limit: limit,
          );
    if (!mounted || request != dataRequest) return;
    setState(() => _data = rows);
  }

  String tooltipText(
    StrengthMetric selectedMetric,
    StrengthData row,
    String format,
  ) {
    final created = formatDisplayDate(context, row.created, format);
    final value = formatDisplayNumber(context, row.value, minDigits: 2);
    final displayUnit = displayMeasurementUnit(context.l10n, targetUnit);
    return switch (selectedMetric) {
      StrengthMetric.bestReps ||
      StrengthMetric.relativeStrength => '$value $created',
      _ => '$value$displayUnit $created',
    };
  }
}
