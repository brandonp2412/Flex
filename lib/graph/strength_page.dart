import 'package:flex/bottom_nav.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/graph/edit_graph_page.dart';
import 'package:flex/graph/exercise_graph_state.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/graph_metric_chips.dart';
import 'package:flex/graph/graph_options_controls.dart';
import 'package:flex/graph/graph_period_picker.dart';
import 'package:flex/graph/strength_data.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
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
  DateTime? pointDate(int index) =>
      index < 0 || index >= _data.length ? null : _data[index].created;

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
    targetUnit = widget.initialUnit;
    exerciseName = widget.initialName;
    final settings = context.read<Setting>();
    timeAxis = settings.defaultGraphTimeBasedXAxis;
    limit = settings.defaultGraphLimit;
    metric = StrengthMetric.values.firstWhere(
      (m) => m.name == settings.defaultGraphMetric,
      orElse: () => StrengthMetric.bestWeight,
    );
    if (!settings.showBodyWeight && metric == StrengthMetric.relativeStrength) {
      metric = StrengthMetric.bestWeight;
    }
    period = Period.values.firstWhere(
      (p) => p.name == settings.defaultGraphPeriod,
      orElse: () => Period.day,
    );
    widget.tabCtrl.addListener(onTabChanged);
    if (!widget.bodyWeight) _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final pref = await getExerciseByName(db, exerciseName);
    if (pref == null || !mounted) return;
    setState(() {
      final stored = pref.graphMetric.split(',');
      final showBodyWeight = context.read<Setting>().showBodyWeight;
      metric = StrengthMetric.values.firstWhere(
        (m) =>
            stored.contains(m.name) &&
            (showBodyWeight || m != StrengthMetric.relativeStrength),
        orElse: () => StrengthMetric.bestWeight,
      );
      period = Period.values.firstWhere(
        (p) => p.name == pref.graphPeriod,
        orElse: () => period,
      );
      limit = pref.graphLimit;
      timeAxis = pref.graphTimeBasedXAxis;
      notesCtrl.text = pref.notes ?? '';
    });
    setData();
  }

  @override
  Widget build(BuildContext context) {
    final showBodyWeight = context.select<Setting, bool>(
      (settings) => settings.showBodyWeight,
    );
    final shortDateFormat = context.select<Setting, String>(
      (settings) => settings.shortDateFormat,
    );
    final showNotes = context.select<Setting, bool>(
      (settings) => settings.showNotes,
    );
    final desktop = isDesktopLayout(context);
    final theme = Theme.of(context);

    final metricOptions = <(StrengthMetric, String)>[
      (StrengthMetric.bestWeight, context.l10n.bestWeight),
      (StrengthMetric.bestReps, context.l10n.bestReps),
      (StrengthMetric.oneRepMax, context.l10n.oneRepMax),
      (StrengthMetric.volume, context.l10n.volume),
      if (showBodyWeight)
        (StrengthMetric.relativeStrength, context.l10n.relativeStrength),
    ];
    final metricSelector = GraphMetricChips<StrengthMetric>(
      options: metricOptions,
      selected: metric,
      onChanged: (next) {
        if (metric == next) return;
        setState(() {
          metric = next;
        });
        setData();
        savePreferences();
      },
    );
    final periodSelector = GraphPeriodPicker(
      selected: period,
      onChanged: (value) {
        setState(() {
          period = value;
        });
        setData();
        savePreferences();
      },
    );

    final palette = GraphMetricChips.palette(theme.colorScheme);
    final lineColor =
        palette[metricOptions.indexWhere((o) => o.$1 == metric) %
            palette.length];
    final points = <FlexLineChartPoint>[];
    for (var index = 0; index < _data.length; index++) {
      points.add(
        FlexLineChartPoint(
          timeAxis
              ? _data[index].created.millisecondsSinceEpoch.toDouble()
              : index.toDouble(),
          _data[index].value,
          column: index,
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(exerciseName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!widget.bodyWeight)
            IconButton(
              onPressed: () async {
                String? newName = await Navigator.of(context).push(
                  FlexPageRoute(
                    builder: (context) => EditGraphPage(name: exerciseName),
                  ),
                );
                if (mounted && newName != null) {
                  setState(() {
                    exerciseName = newName;
                  });
                }
              },
              icon: const Icon(Icons.edit),
              tooltip: context.l10n.actionEdit,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: desktop ? 24.0 : bottomNavHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              periodSelector,
              if (!widget.bodyWeight) ...[
                const SizedBox(height: 8),
                metricSelector,
              ],
              const SizedBox(height: 8),
              Expanded(
                child: _data.isEmpty
                    ? AppEmptyState(
                        icon: Icons.fitness_center_rounded,
                        title: context.l10n.noDataYet,
                        message: context.l10n.completeSetForChart,
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 16.0, right: 45.0),
                        child: FlexLineChart(
                          lineColor: lineColor,
                          dates: _data.map((row) => row.created).toList(),
                          points: points,
                          tooltipText: (index) => tooltipText(
                            metric,
                            _data[index],
                            shortDateFormat,
                          ),
                          onPointSelected: touchLine,
                          timeBasedXAxis: timeAxis,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              GraphActionButtons(
                onHistory: showHistory,
                onOptions: showOptions,
              ),
              const SizedBox(height: 8),
              if (showNotes) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextField(
                    controller: notesCtrl,
                    readOnly: true,
                    onTap: editNotes,
                    decoration: InputDecoration(
                      labelText: context.l10n.exerciseNotes,
                      hintText: context.l10n.notesForExercise,
                    ),
                    minLines: 2,
                    maxLines: 5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
