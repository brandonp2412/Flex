import 'dart:async';

import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/graph/flex_line_chart.dart';
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

abstract class ExerciseGraphState<T extends StatefulWidget, M extends Enum>
    extends GraphFilterState<T> {
  late String exerciseName;
  late bool timeAxis;
  late M metric;
  int dataRequest = 0;
  late Period period;
  DateTime lastTap = DateTime(0);
  Timer? _refreshTimer;
  Timer? _notesDebounce;
  final notesCtrl = TextEditingController();

  TabController get tabController;
  bool get bodyWeight => false;
  List<({DateTime created, double value})> get chartRows;
  List<(M, String)> get metricOptions;
  M defaultMetric(Setting settings);
  M storedMetric(List<String> stored);
  bool get showNotes => true;
  bool get cardio => false;
  String tooltip(int index, String format);
  Future<void> editGraph();

  DateTime? pointDate(int index);

  void initialize(String name, String unit) {
    exerciseName = name;
    targetUnit = unit;
    final settings = context.read<Setting>();
    timeAxis = settings.defaultGraphTimeBasedXAxis;
    limit = settings.defaultGraphLimit;
    metric = defaultMetric(settings);
    period = Period.values.firstWhere(
      (p) => p.name == settings.defaultGraphPeriod,
      orElse: () => Period.day,
    );
    tabController.addListener(onTabChanged);
    if (!bodyWeight) loadPreferences();
  }

  Future<void> loadPreferences() async {
    final pref = await getExerciseByName(db, exerciseName);
    if (pref == null || !mounted) return;
    setState(() {
      metric = storedMetric(pref.graphMetric.split(','));
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
    final rows = chartRows;
    final notesVisible = showNotes;
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
                GraphMetricChips<M>(
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
                                rows[i].value,
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
    await Navigator.of(context, rootNavigator: true).push(
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
    tabController.removeListener(onTabChanged);
    super.dispose();
  }

  void onTabChanged() {
    final settings = context.read<Setting>();
    if (tabController.index == settings.tabs.split(',').indexOf('GraphsPage')) {
      setData();
    }
  }

  Future<void> showHistory() async {
    final exerciseSets = bodyWeight
        ? await getBodyWeightGraphHistory()
        : await getGraphHistory(exerciseName);
    if (!mounted) return;

    final desktop = isDesktopLayout(context);
    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => GraphHistoryPage(
          name: exerciseName,
          initialSets: exerciseSets,
          tabController: tabController,
          bodyWeight: bodyWeight,
        ),
      ),
    );
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
    final created = pointDate(index);
    if (created == null) return;
    final desktop = isDesktopLayout(context);
    final exerciseSet = await getGraphPointSet(exerciseName, created);
    if (!mounted || exerciseSet == null) return;

    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => EditSetPage(exerciseSet: exerciseSet),
      ),
    );
    _refreshTimer?.cancel();
    if (desktop) {
      setData();
    } else {
      _refreshTimer = Timer(kThemeAnimationDuration, setData);
    }
  }
}
