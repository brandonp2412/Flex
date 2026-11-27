import 'dart:async';

import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/graph_data.dart';
import 'package:flex/graph/exercise_editor_page.dart';
import 'package:flex/utils.dart';
import 'package:flex/graph/graph_metric_chips.dart';
import 'package:flex/graph/graph_period_picker.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/graph/graph_history_page.dart';
import 'package:flex/graph/graph_notes_page.dart';
import 'package:flex/graph/graph_options_controls.dart';
import 'package:flex/graph/graph_filter_state.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExerciseGraphPage extends StatefulWidget {
  const ExerciseGraphPage({
    super.key,
    required this.initialName,
    required this.initialUnit,
    required this.initialData,
    required this.tabCtrl,
    this.cardio = false,
    this.bodyWeight = false,
  });

  final String initialName;
  final String initialUnit;
  final List<GraphData> initialData;
  final TabController tabCtrl;
  final bool cardio;
  final bool bodyWeight;

  @override
  State<ExerciseGraphPage> createState() => _ExerciseGraphPageState();
}

class _ExerciseGraphPageState extends GraphFilterState<ExerciseGraphPage> {
  late String exerciseName;
  late bool timeAxis;
  late Enum metric;
  late List<GraphData> data;
  late Period period;
  DateTime lastTap = DateTime(0);
  Timer? _refreshTimer;
  Timer? _notesDebounce;
  final notesCtrl = TextEditingController();

  @override
  TabController get graphTabController => widget.tabCtrl;
  bool get bodyWeight => widget.bodyWeight;
  bool get cardio => widget.cardio;
  bool get weightedCardio => isWeightUnit(targetUnit);

  Enum get fallbackMetric => !cardio
      ? StrengthMetric.bestWeight
      : weightedCardio
      ? CardioMetric.weight
      : CardioMetric.pace;

  List<CardioMetric> get allowedCardioMetrics => weightedCardio
      ? [CardioMetric.weight, CardioMetric.duration, CardioMetric.incline]
      : [
          CardioMetric.pace,
          CardioMetric.inclineAdjustedPace,
          CardioMetric.duration,
          CardioMetric.distance,
          CardioMetric.incline,
        ];

  Enum selectMetric(
    List<String> names,
    Setting settings, {
    bool initial = false,
  }) {
    if (cardio) {
      if (initial && weightedCardio) return CardioMetric.weight;
      return CardioMetric.values.firstWhere(
        (value) =>
            names.contains(value.name) &&
            (initial || allowedCardioMetrics.contains(value)),
        orElse: () => fallbackMetric as CardioMetric,
      );
    }
    return StrengthMetric.values.firstWhere(
      (value) =>
          names.contains(value.name) &&
          (settings.showBodyWeight || value != StrengthMetric.relativeStrength),
      orElse: () => StrengthMetric.bestWeight,
    );
  }

  List<(Enum, String)> get metricOptions {
    final l10n = context.l10n;
    if (cardio) {
      return [
        for (final value in allowedCardioMetrics)
          (
            value,
            switch (value) {
              CardioMetric.weight => l10n.weightLabel,
              CardioMetric.duration => l10n.durationLabel,
              CardioMetric.incline => l10n.inclineLabel,
              CardioMetric.pace => l10n.paceDistanceTime,
              CardioMetric.inclineAdjustedPace => l10n.adjustedPace,
              CardioMetric.distance => l10n.distanceLabel,
            },
          ),
      ];
    }
    return strengthMetricOptions(
      context,
      showBodyWeight: context.select<Setting, bool>(
        (settings) => settings.showBodyWeight,
      ),
    );
  }

  @override
  List<DropdownMenuItem<String>> get optionsUnits {
    if (!context.read<Setting>().showUnits) return const [];
    if (!cardio || metric == CardioMetric.weight)
      return strengthUnitMenuItems(context.l10n);
    if (metric == CardioMetric.distance)
      return cardioDistanceUnitMenuItems(context.l10n);
    return const [];
  }

  @override
  void initState() {
    super.initState();
    exerciseName = widget.initialName;
    targetUnit = widget.initialUnit;
    data = widget.initialData;
    final settings = context.read<Setting>();
    timeAxis = settings.defaultGraphTimeBasedXAxis;
    limit = settings.defaultGraphLimit;
    metric = selectMetric(
      [settings.defaultGraphMetric],
      settings,
      initial: true,
    );
    period = Period.values.firstWhere(
      (p) => p.name == settings.defaultGraphPeriod,
      orElse: () => Period.day,
    );
    if (!bodyWeight) loadPreferences();
  }

  @override
  Future<void> setData() async {
    if (!mounted) return;
    final request = beginDataRequest();
    final rows = await getExerciseGraphData(
      name: exerciseName,
      target: targetUnit,
      bodyWeight: bodyWeight,
      metric: metric,
      period: period,
      start: start,
      end: end,
      limit: limit,
    );
    if (isCurrentDataRequest(request)) setState(() => data = rows);
  }

  Future<void> editGraph() async {
    final name = await Navigator.of(context).push<String>(
      FlexPageRoute(
        builder: (context) => ExerciseEditorPage.edit(name: exerciseName),
      ),
    );
    if (!mounted || name == null) return;
    final updated = cardio ? await getExerciseByName(db, name) : null;
    if (!mounted) return;
    setState(() {
      exerciseName = name;
      if (cardio) {
        if (updated != null) targetUnit = updated.displayUnit;
        if (!allowedCardioMetrics.contains(metric)) metric = fallbackMetric;
      }
    });
    if (cardio) setData();
  }

  String tooltip(int index, String format) {
    final row = data[index];
    final created = formatDisplayDate(context, row.created, format);
    final value = formatDisplayNumber(context, row.value, minDigits: 2);
    if (!cardio) {
      final unit = displayMeasurementUnit(context.l10n, targetUnit);
      return metric == StrengthMetric.bestReps ||
              metric == StrengthMetric.relativeStrength
          ? '$value $created'
          : '$value$unit $created';
    }
    final unit = displayMeasurementUnit(context.l10n, row.unit);
    final text = switch (metric) {
      CardioMetric.pace =>
        '${formatDisplayNumber(context, row.value)} $unit / ${context.l10n.minutesShort}',
      CardioMetric.duration =>
        '${row.value.floor()}:${((row.value * 60) % 60).floor().toString().padLeft(2, '0')}',
      CardioMetric.distance || CardioMetric.weight => '$value $unit',
      CardioMetric.incline => formatDisplayPercent(context, row.value / 100),
      _ => value,
    };
    return '$text\n$created';
  }

  Future<void> loadPreferences() async {
    final pref = await getExerciseByName(db, exerciseName);
    if (pref == null || !mounted) return;
    setState(() {
      metric = selectMetric(
        pref.graphMetric.split(','),
        context.read<Setting>(),
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
    final shortDateFormat = context.select<Setting, String>(
      (settings) => settings.shortDateFormat,
    );
    final options = metricOptions;
    final palette = GraphMetricChips.palette(Theme.of(context).colorScheme);
    final rows = data;
    final notesVisible =
        cardio ||
        context.select<Setting, bool>((settings) => settings.showNotes);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(exerciseName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!bodyWeight)
            IconButton(
              onPressed: editGraph,
              icon: const Icon(Icons.edit),
              tooltip: context.l10n.actionEdit,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: isDesktopLayout(context) ? 24 : bottomNavHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              GraphPeriodPicker(
                selected: period,
                onChanged: (value) => changeSelection(() => period = value),
              ),
              if (!bodyWeight) ...[
                const SizedBox(height: 8),
                GraphMetricChips<Enum>(
                  options: options,
                  selected: metric,
                  onChanged: (value) {
                    if (metric != value) changeSelection(() => metric = value);
                  },
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: rows.isEmpty
                    ? AppEmptyState(
                        icon: cardio
                            ? Icons.monitor_heart_outlined
                            : Icons.fitness_center_rounded,
                        title: cardio
                            ? context.l10n.noDataFor(exerciseName)
                            : context.l10n.noDataYet,
                        message: context.l10n.completeSetForChart,
                      )
                    : Padding(
                        padding: EdgeInsets.only(
                          top: 16,
                          right: cardio ? 32 : 45,
                        ),
                        child: FlexLineChart(
                          lineColor:
                              palette[options.indexWhere(
                                    (o) => o.$1 == metric,
                                  ) %
                                  palette.length],
                          dates: rows.map((row) => row.created).toList(),
                          points: [
                            for (var i = 0; i < rows.length; i++)
                              FlexLineChartPoint(
                                timeAxis
                                    ? rows[i].created.millisecondsSinceEpoch
                                          .toDouble()
                                    : i.toDouble(),
                                cardio
                                    ? double.parse(
                                        rows[i].value.toStringAsFixed(1),
                                      )
                                    : rows[i].value,
                                column: i,
                              ),
                          ],
                          tooltipText: (index) =>
                              tooltip(index, shortDateFormat),
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
              if (notesVisible)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
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
              if (cardio) const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void changeSelection(VoidCallback change) {
    setState(change);
    setData();
    savePreferences();
  }

  Future<void> savePreferences() async {
    if (bodyWeight) return;
    final exercise = await getExerciseByName(db, exerciseName);
    if (exercise == null) return;
    await updateExerciseGraphPreferences(
      db,
      exerciseId: exercise.id,
      metric: metric.name,
      period: period.name,
      limit: limit,
      timeBasedXAxis: timeAxis,
      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
    );
  }

  void _onNotesChanged() {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 600), savePreferences);
  }

  Future<void> editNotes() async {
    await Navigator.of(context, rootNavigator: !isDesktopLayout(context)).push(
      FlexPageRoute(
        builder: (context) =>
            GraphNotesPage(controller: notesCtrl, onChanged: _onNotesChanged),
      ),
    );
    _notesDebounce?.cancel();
    await savePreferences();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notesDebounce?.cancel();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> showHistory() async {
    final exerciseSets = await getGraphHistory(
      exerciseName,
      bodyWeight: bodyWeight,
    );
    if (!mounted) return;

    final desktop = isDesktopLayout(context);
    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => GraphHistoryPage(
          name: exerciseName,
          initialSets: exerciseSets,
          tabController: graphTabController,
          bodyWeight: bodyWeight,
        ),
      ),
    );
    refreshAfterNavigation(desktop);
  }

  void refreshAfterNavigation(bool desktop) {
    if (!mounted) return;
    _refreshTimer?.cancel();
    if (desktop) {
      setData();
    } else {
      _refreshTimer = Timer(kThemeAnimationDuration, setData);
    }
  }

  @override
  bool? get optionsTimeAxis => timeAxis;

  @override
  void onLimitUpdated() => savePreferences();

  @override
  void onTimeAxisUpdated(bool value) {
    timeAxis = value;
    savePreferences();
  }

  Future<void> touchLine(int index) async {
    if (DateTime.now().difference(lastTap) >=
        const Duration(milliseconds: 300)) {
      lastTap = DateTime.now();
      return;
    }

    if (bodyWeight) return;
    if (index < 0 || index >= data.length) return;
    final created = data[index].created;
    final desktop = isDesktopLayout(context);
    final exerciseSet = await ExerciseSetQuery(
      db,
      exerciseName: exerciseName,
      timestamp: created,
    ).firstOrNull();
    if (!mounted || exerciseSet == null) return;

    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => EditSetPage(exerciseSet: exerciseSet),
      ),
    );
    refreshAfterNavigation(desktop);
  }
}
