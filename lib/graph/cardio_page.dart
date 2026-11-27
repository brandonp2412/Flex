import 'package:flex/bottom_nav.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/graph/cardio_data.dart';
import 'package:flex/graph/edit_graph_page.dart';
import 'package:flex/graph/exercise_graph_state.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/graph_metric_chips.dart';
import 'package:flex/graph/graph_options_controls.dart';
import 'package:flex/graph/graph_period_picker.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
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
  DateTime? pointDate(int index) =>
      index < 0 || index >= _data.length ? null : _data[index].created;

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
    targetUnit = widget.initialUnit;
    exerciseName = widget.initialName;
    final settings = context.read<Setting>();
    timeAxis = settings.defaultGraphTimeBasedXAxis;
    limit = settings.defaultGraphLimit;
    metric = isWeightUnit(targetUnit)
        ? CardioMetric.weight
        : CardioMetric.values.firstWhere(
            (m) => m.name == settings.defaultGraphMetric,
            orElse: () => CardioMetric.pace,
          );
    period = Period.values.firstWhere(
      (p) => p.name == settings.defaultGraphPeriod,
      orElse: () => Period.day,
    );
    widget.tabCtrl.addListener(onTabChanged);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final pref = await getExerciseByName(db, exerciseName);
    if (pref == null || !mounted) return;
    setState(() {
      final stored = pref.graphMetric.split(',');
      final allowed = isWeightUnit(targetUnit)
          ? {CardioMetric.weight, CardioMetric.duration, CardioMetric.incline}
          : {
              CardioMetric.pace,
              CardioMetric.inclineAdjustedPace,
              CardioMetric.duration,
              CardioMetric.distance,
              CardioMetric.incline,
            };
      metric = CardioMetric.values.firstWhere(
        (m) => stored.contains(m.name) && allowed.contains(m),
        orElse: () =>
            isWeightUnit(targetUnit) ? CardioMetric.weight : CardioMetric.pace,
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
  Widget build(BuildContext context) {
    final shortDateFormat = context.select<Setting, String>(
      (settings) => settings.shortDateFormat,
    );
    final desktop = isDesktopLayout(context);
    final theme = Theme.of(context);

    final metricOptions = isWeightUnit(targetUnit)
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

    final metricSelector = GraphMetricChips<CardioMetric>(
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
      final row = _data[index];
      final value = double.parse(row.value.toStringAsFixed(1));
      points.add(
        FlexLineChartPoint(
          timeAxis
              ? row.created.millisecondsSinceEpoch.toDouble()
              : index.toDouble(),
          value,
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
          IconButton(
            onPressed: () async {
              final newName = await Navigator.of(context).push<String>(
                FlexPageRoute(
                  builder: (context) => EditGraphPage(name: exerciseName),
                ),
              );
              if (mounted && newName != null) {
                final updated = await getExerciseByName(db, newName);
                if (!mounted) return;
                setState(() {
                  exerciseName = newName;
                  if (updated != null) targetUnit = updated.displayUnit;
                  final supportsWeight = isWeightUnit(targetUnit);
                  final allowed = supportsWeight
                      ? {
                          CardioMetric.weight,
                          CardioMetric.duration,
                          CardioMetric.incline,
                        }
                      : {
                          CardioMetric.pace,
                          CardioMetric.inclineAdjustedPace,
                          CardioMetric.duration,
                          CardioMetric.distance,
                          CardioMetric.incline,
                        };
                  if (!allowed.contains(metric)) {
                    metric = supportsWeight
                        ? CardioMetric.weight
                        : CardioMetric.pace;
                  }
                });
                setData();
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
              const SizedBox(height: 8),
              metricSelector,
              const SizedBox(height: 8),
              Expanded(
                child: _data.isEmpty
                    ? AppEmptyState(
                        icon: Icons.monitor_heart_outlined,
                        title: context.l10n.noDataFor(exerciseName),
                        message: context.l10n.completeSetForChart,
                      )
                    : Padding(
                        padding: const EdgeInsets.only(right: 32.0, top: 16.0),
                        child: FlexLineChart(
                          lineColor: lineColor,
                          points: points,
                          tooltipText: (index) => tooltipText(
                            metric,
                            _data[index],
                            shortDateFormat,
                          ),
                          onPointSelected: touchLine,
                          dates: _data.map((row) => row.created).toList(),
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
              const SizedBox(height: 8),
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
