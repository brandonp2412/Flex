import 'package:drift/drift.dart' hide Column;

import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/error_state.dart';
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
    this.cardio = false,
    this.bodyWeight = false,
  });

  final String initialName;
  final String initialUnit;
  final bool cardio;
  final bool bodyWeight;

  @override
  State<ExerciseGraphPage> createState() => _ExerciseGraphPageState();
}

class _ExerciseGraphPageState extends State<ExerciseGraphPage> {
  late String _name = widget.initialName;
  late Stream<Exercise?> _exercise = watchExerciseByName(db, _name);

  Future<void> _editGraph() async {
    final name = await Navigator.of(context).push<String>(
      FlexPageRoute(builder: (context) => ExerciseEditorPage.edit(name: _name)),
    );
    if (!mounted || name == null || name == _name) return;
    setState(() {
      _name = name;
      _exercise = watchExerciseByName(db, name);
    });
  }

  Widget _content(Exercise? exercise) => _ExerciseGraphContent(
    name: _name,
    unit: widget.initialUnit,
    exercise: exercise,
    bodyWeight: widget.bodyWeight,
    initialCardio: widget.cardio,
    onEdit: _editGraph,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.bodyWeight) return _content(null);
    return StreamBuilder<Exercise?>(
      stream: _exercise,
      builder: (context, snapshot) =>
          snapshot.hasError ? const AppErrorState() : _content(snapshot.data),
    );
  }
}

class _ExerciseGraphContent extends StatefulWidget {
  const _ExerciseGraphContent({
    required this.name,
    required this.unit,
    required this.exercise,
    required this.bodyWeight,
    required this.initialCardio,
    required this.onEdit,
  });

  final String name;
  final String unit;
  final Exercise? exercise;
  final bool bodyWeight;
  final bool initialCardio;
  final VoidCallback onEdit;

  @override
  State<_ExerciseGraphContent> createState() => _ExerciseGraphContentState();
}

class _ExerciseGraphContentState
    extends GraphFilterState<_ExerciseGraphContent> {
  int? _localLimit;
  bool? _localTimeAxis;
  Period? _localPeriod;
  String? _unitOverride;
  late Stream<List<GraphData>> _data;
  ({
    String name,
    String unit,
    Enum metric,
    Period period,
    DateTime? start,
    DateTime? end,
    int limit,
  })?
  _query;
  DateTime lastTap = DateTime(0);

  String get exerciseName => widget.name;
  bool get bodyWeight => widget.bodyWeight;
  bool get cardio =>
      !bodyWeight &&
      (widget.exercise?.kind == 'cardio' ||
          (widget.exercise == null && widget.initialCardio));
  bool get weightedCardio => isWeightUnit(targetUnit);
  Setting get settings => context.read<Setting>();

  @override
  String get targetUnit =>
      _unitOverride ??
      (cardio ? widget.exercise?.displayUnit : null) ??
      widget.unit;

  @override
  set targetUnit(String value) => _unitOverride = value;

  @override
  int get limit =>
      widget.exercise?.graphLimit ?? _localLimit ?? settings.defaultGraphLimit;

  bool get timeAxis =>
      widget.exercise?.graphTimeBasedXAxis ??
      _localTimeAxis ??
      settings.defaultGraphTimeBasedXAxis;

  Period get period => Period.values.firstWhere(
    (value) =>
        value.name ==
        (widget.exercise?.graphPeriod ??
            _localPeriod?.name ??
            settings.defaultGraphPeriod),
    orElse: () => Period.day,
  );

  Enum get metric => selectMetric(
    (widget.exercise?.graphMetric ?? settings.defaultGraphMetric).split(','),
    settings,
  );

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

  Enum selectMetric(List<String> names, Setting settings) {
    if (cardio) {
      return CardioMetric.values.firstWhere(
        (value) =>
            names.contains(value.name) && allowedCardioMetrics.contains(value),
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
  void didUpdateWidget(_ExerciseGraphContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise?.displayUnit != null &&
        widget.exercise?.displayUnit != null &&
        oldWidget.exercise?.displayUnit != widget.exercise?.displayUnit) {
      _unitOverride = null;
    }
    if (oldWidget.exercise != widget.exercise) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshOptions();
      });
    }
  }

  @override
  void setData() {
    final query = (
      name: exerciseName,
      unit: targetUnit,
      metric: metric,
      period: period,
      start: start,
      end: end,
      limit: limit,
    );
    if (_query == query) return;
    _query = query;
    _data = watchExerciseGraphData(
      name: query.name,
      target: query.unit,
      bodyWeight: bodyWeight,
      metric: query.metric,
      period: query.period,
      start: query.start,
      end: query.end,
      limit: query.limit,
    );
  }

  String tooltip(GraphData row, String format) {
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

  @override
  Widget build(BuildContext context) {
    context.watch<Setting>();
    setData();
    final shortDateFormat = context.select<Setting, String>(
      (settings) => settings.shortDateFormat,
    );
    final options = metricOptions;
    final palette = GraphMetricChips.palette(Theme.of(context).colorScheme);
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
              onPressed: widget.onEdit,
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
              GraphPeriodPicker(selected: period, onChanged: _changePeriod),
              if (!bodyWeight) ...[
                const SizedBox(height: 8),
                GraphMetricChips<Enum>(
                  options: options,
                  selected: metric,
                  onChanged: (value) {
                    if (metric != value)
                      _writePreference(
                        ExercisesCompanion(graphMetric: Value(value.name)),
                      );
                  },
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<GraphData>>(
                  key: ValueKey(_query),
                  stream: _data,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const AppErrorState();
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final rows = snapshot.data!;
                    return rows.isEmpty
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
                                  tooltip(rows[index], shortDateFormat),
                              onPointSelected: (index) =>
                                  touchLine(rows[index]),
                              timeBasedXAxis: timeAxis,
                            ),
                          );
                  },
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
                  child: InkWell(
                    onTap: editNotes,
                    child: InputDecorator(
                      isEmpty: widget.exercise?.notes?.isNotEmpty != true,
                      decoration: InputDecoration(
                        labelText: context.l10n.exerciseNotes,
                        hintText: context.l10n.notesForExercise,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Text(
                          widget.exercise?.notes ?? '',
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              if (cardio) const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _writePreference(ExercisesCompanion update) async {
    final exercise = widget.exercise;
    if (exercise == null) return;
    await (db.exercises.update()..where((row) => row.id.equals(exercise.id)))
        .write(update);
  }

  void _changePeriod(Period value) {
    if (widget.exercise == null) {
      setState(() => _localPeriod = value);
      return;
    }
    _writePreference(ExercisesCompanion(graphPeriod: Value(value.name)));
  }

  Future<void> editNotes() async {
    final exercise = widget.exercise;
    if (exercise == null) return;
    final database = db;
    await Navigator.of(context, rootNavigator: !isDesktopLayout(context)).push(
      FlexPageRoute(
        builder: (context) => GraphNotesPage(
          initialNotes: exercise.notes ?? '',
          onSave: (text) =>
              (database.exercises.update()
                    ..where((row) => row.id.equals(exercise.id)))
                  .write(
                    ExercisesCompanion(
                      notes: Value(text.isEmpty ? null : text),
                    ),
                  ),
        ),
      ),
    );
  }

  Future<void> showHistory() async {
    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) =>
            GraphHistoryPage(name: exerciseName, bodyWeight: bodyWeight),
      ),
    );
  }

  @override
  bool? get optionsTimeAxis => timeAxis;

  @override
  void onLimitChanged(int value) {
    if (widget.exercise == null) {
      _localLimit = value;
    } else {
      _writePreference(ExercisesCompanion(graphLimit: Value(value)));
    }
  }

  @override
  void onTimeAxisUpdated(bool value) {
    if (widget.exercise == null) {
      _localTimeAxis = value;
    } else {
      _writePreference(ExercisesCompanion(graphTimeBasedXAxis: Value(value)));
    }
  }

  Future<void> touchLine(GraphData point) async {
    if (DateTime.now().difference(lastTap) >=
        const Duration(milliseconds: 300)) {
      lastTap = DateTime.now();
      return;
    }

    if (bodyWeight) return;
    final created = point.created;
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
  }
}
