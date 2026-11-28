import 'dart:async';
import 'package:flex/desktop_editor_save_button.dart';
import 'package:flex/sets/workout_input.dart';
import 'package:flex/app_message.dart';
import 'package:flex/sets/workout_unit_field.dart';
import 'package:flex/sets/workout_number_field.dart';
import 'dart:math';

import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/error_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/permissions_page.dart';
import 'package:flex/plan/edit_plan_page.dart';
import 'package:flex/plan/session_sets.dart';
import 'package:flex/plan/start_list.dart';
import 'package:flex/plan/start_plan_compact_layout.dart';
import 'package:flex/plan/start_plan_data.dart';
import 'package:flex/plan/start_plan_dock_location.dart';
import 'package:flex/plan/start_plan_wide_layout.dart';
import 'package:flex/plan/workout_sessions.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flex/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> openStartPlan(
  NavigatorState navigator,
  Plan plan, {
  List<PlanExerciseEntry>? initial,
}) async {
  Future<void> push({StartPlanData? data, Stream<StartPlanData>? stream}) =>
      navigator.push<void>(
        FlexPageRoute<void>(
          settings: RouteSettings(name: 'start-plan:${plan.id}'),
          snapshotOnPop: true,
          builder: (context) => StartPlanPage(
            plan: plan,
            initial: initial,
            initialData: data,
            initialStream: stream,
          ),
        ),
      );

  if (!isDesktopLayout(navigator.context)) return push();

  final ready = Completer<StartPlanData>();
  final controller = StreamController<StartPlanData>();
  final subscription = watchStartPlanData(db, plan.id).listen(
    (data) {
      if (!ready.isCompleted) {
        ready.complete(data);
      } else {
        controller.add(data);
      }
    },
    onError: (Object error, StackTrace stack) {
      if (!ready.isCompleted) {
        ready.completeError(error, stack);
      } else {
        controller.addError(error, stack);
      }
    },
    onDone: () {
      if (!ready.isCompleted) {
        ready.completeError(StateError('Workout data unavailable'));
      }
      unawaited(controller.close());
    },
  );
  controller.onCancel = subscription.cancel;
  try {
    StartPlanData data;
    try {
      data = await ready.future;
    } catch (_) {
      if (navigator.mounted) await push();
      return;
    }
    if (navigator.mounted) await push(data: data, stream: controller.stream);
  } finally {
    await subscription.cancel();
    unawaited(controller.close());
  }
}

class StartPlanPage extends StatefulWidget {
  final Plan plan;
  final List<PlanExerciseEntry>? initial;
  final StartPlanData? initialData;
  final Stream<StartPlanData>? initialStream;
  const StartPlanPage({
    super.key,
    required this.plan,
    this.initial,
    this.initialData,
    this.initialStream,
  });

  @override
  createState() => _StartPlanPageState();
}

class _StartPlanPageState extends State<StartPlanPage>
    with WidgetsBindingObserver {
  final _notes = TextEditingController(text: "");
  final _repsFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _minutesFocus = FocusNode();
  final _secondsFocus = FocusNode();
  final _distanceFocus = FocusNode();
  final _inclineFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _input = WorkoutInput(session: true);
  final _key = GlobalKey<FormState>();

  int? _selectedExerciseId;
  bool _saving = false;
  DateTime? _lastSavedAt;
  String _unit = 'kg';
  late Stream<StartPlanData> _stream;

  int _selectedIndex(List<PlanExerciseEntry> exercises) {
    final index = exercises.indexWhere(
      (entry) => entry.exercise.id == _selectedExerciseId,
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StartPlanData>(
      stream: _stream,
      initialData: widget.initialData,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final exercises = data?.exercises ?? widget.initial;
        final workout = data?.workout;
        if (exercises == null || snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_displayTitle(context, data?.plan ?? widget.plan)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: snapshot.hasError
                  ? const AppErrorState()
                  : const SizedBox.shrink(),
            ),
          );
        }

        final selected = _selectedIndex(exercises);
        final exercise = exercises.elementAtOrNull(selected)?.exercise;
        final cardio = exercise?.kind == 'cardio';
        Future<void> save() => _save(data, selected);

        final desktop = isDesktopLayout(context);

        Future<void> editPlan() async {
          final plan = data?.plan ?? widget.plan;
          if (!context.mounted) return;
          await Navigator.of(context).push(
            FlexPageRoute(
              builder: (context) => EditPlanPage(plan: plan.toCompanion(false)),
            ),
          );
          if (!mounted) return;
        }

        final exerciseList = exercises.isEmpty
            ? AppEmptyState(
                icon: Icons.fitness_center_rounded,
                title: context.l10n.noExercisesYet,
                message: context.l10n.addExerciseToPlan,
                actionLabel: context.l10n.editPlan,
                actionIcon: Icons.edit_rounded,
                onAction: editPlan,
              )
            : StartList(
                exercises: exercises,
                selected: selected,
                onSelect: (index) async =>
                    setState(() => _select(exercises, data?.defaults, index)),
                sets: data?.sets ?? const {},
                workoutId: workout?.id,
              );

        final fields = [
          if (cardio)
            ...cardioFields(exercise, save)
          else
            ...strengthFields(exercise, save),
          unitSelector(),
          notesField(save),
        ];
        final sessionSets = workout == null || exercise == null
            ? null
            : SessionSets(
                key: desktop ? null : const Key('start-plan-set-preview'),
                exerciseId: exercise.id,
                workoutId: workout.id,
                previous: data?.previous[exercise.id],
                onPreviousSetTap: _fillPreviousSet,
                sets: data?.sets[exercise.id] ?? const [],
                compact: !desktop,
              );

        return Scaffold(
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(_displayTitle(context, data?.plan ?? widget.plan)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: context.l10n.editPlan,
                onPressed: editPlan,
                icon: const Icon(Icons.edit),
              ),
              if (desktop && exercises.isNotEmpty)
                DesktopEditorSaveButton(
                  onPressed: save,
                  label: context.l10n.saveSet,
                ),
            ],
          ),
          body: ResponsiveContent(
            maxWidth: wideMaxWidth,
            desktopPadding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            mobilePadding: const EdgeInsets.all(8),
            child: Form(
              key: _key,
              child: desktop
                  ? StartPlanWideLayout(
                      title: exercise?.name ?? context.l10n.setDetails,
                      fields: fields,
                      exerciseList: exerciseList,
                      sessionSets: sessionSets,
                    )
                  : StartPlanCompactLayout(
                      fields: fields,
                      exerciseList: exerciseList,
                    ),
            ),
          ),
          floatingActionButtonLocation: desktop
              ? FloatingActionButtonLocation.centerFloat
              : StartPlanDockLocation(MediaQuery.viewPaddingOf(context).bottom),
          floatingActionButton: desktop || sessionSets == null
              ? null
              : StartPlanCompactDock(sessionSets: sessionSets, onSave: save),
        );
      },
    );
  }

  List<Widget> strengthFields(Exercise? exercise, AsyncCallback save) {
    return [
      _input.field(
        context,
        WorkoutMetric.reps,
        focus: _repsFocus,
        step: 1,
        action: TextInputAction.next,
        onSubmitted: (_) => _focusAndSelect(_weightFocus, _input.weight),
      ),
      const SizedBox(height: 8.0),
      _weightField(exercise, save),
    ];
  }

  List<Widget> cardioFields(Exercise? exercise, AsyncCallback save) {
    final showNotes = context.read<Setting>().showNotes;

    return [
      _input.durationFields(
        context,
        minutesFocus: _minutesFocus,
        secondsFocus: _secondsFocus,
        onMinutesSubmitted: (_) =>
            _focusAndSelect(_secondsFocus, _input.seconds),
        onSecondsSubmitted: (_) {
          if (isWeightUnit(_unit)) {
            _focusAndSelect(_weightFocus, _input.weight);
          } else {
            _focusAndSelect(_distanceFocus, _input.distance);
          }
        },
      ),
      const SizedBox(height: 8.0),
      Row(
        children: [
          if (isWeightUnit(_unit))
            Expanded(child: _weightField(exercise, save))
          else
            Expanded(
              child: _input.field(
                context,
                WorkoutMetric.distance,
                action: TextInputAction.next,
                focus: _distanceFocus,
                onSubmitted: (_) =>
                    _focusAndSelect(_inclineFocus, _input.incline),
              ),
            ),
          const SizedBox(width: 8.0),
          Expanded(
            child: _input.field(
              context,
              WorkoutMetric.incline,
              focus: _inclineFocus,
              action: showNotes ? TextInputAction.next : TextInputAction.done,
              onSubmitted: (_) async {
                if (showNotes) {
                  _focusAndSelect(_notesFocus, _notes);
                } else {
                  await save();
                }
              },
            ),
          ),
        ],
      ),
    ];
  }

  WorkoutNumberField _weightField(Exercise? exercise, AsyncCallback save) {
    final exerciseName = exercise?.name ?? '';
    final cardio = exercise?.kind == 'cardio';
    final showNotes = context.read<Setting>().showNotes;
    final hasNextField = cardio || showNotes;

    return _input.field(
      context,
      WorkoutMetric.weight,
      focus: _weightFocus,
      label: context.l10n.weightWithUnit(_unit),
      step: weightStep(exerciseName, _unit),
      suffixIcon: Selector<Setting, bool>(
        selector: (context, settings) => settings.showBodyWeight,
        builder: (context, showBodyWeight, child) => Visibility(
          visible: showBodyWeight,
          child: IconButton(
            tooltip: context.l10n.useBodyWeight,
            icon: const Icon(Icons.scale),
            onPressed: useBodyWeight,
          ),
        ),
      ),
      action: hasNextField ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) async {
        if (cardio) {
          _focusAndSelect(_inclineFocus, _input.incline);
        } else if (showNotes) {
          _focusAndSelect(_notesFocus, _notes);
        } else {
          await save();
        }
      },
    );
  }

  Widget unitSelector() => WorkoutUnitField(
    unit: _unit,
    inWorkout: true,
    onChanged: (value) => setState(() => _unit = value),
  );

  Widget notesField(AsyncCallback save) {
    return Selector<Setting, bool>(
      selector: (context, settings) => settings.showNotes,
      builder: (context, showNotes, child) => Visibility(
        visible: showNotes,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8.0),
            TextFormField(
              controller: _notes,
              focusNode: _notesFocus,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: context.l10n.notesLabel),
              onFieldSubmitted: (_) async => await save(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    if (!mounted || _lastSavedAt == null) return;

    final settings = context.read<Setting>();
    final difference = DateTime.now().difference(_lastSavedAt!);

    if (_minutesFocus.context != null && settings.durationEstimation) {
      _input.durationInput.fill(difference);
    }
  }

  void _focusAndSelect(FocusNode focusNode, TextEditingController controller) {
    focusNode.requestFocus();
    selectAll(controller);
  }

  @override
  void dispose() {
    _input.dispose();
    _notes.dispose();
    _repsFocus.dispose();
    _weightFocus.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    _distanceFocus.dispose();
    _inclineFocus.dispose();
    _notesFocus.dispose();

    WidgetsBinding.instance.removeObserver(this);
    dbVersion.removeListener(_reloadDatabaseStreams);

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dbVersion.addListener(_reloadDatabaseStreams);
    final initial = widget.initial;
    if (initial != null && initial.isNotEmpty)
      _unit = initial.first.exercise.displayUnit;
    final data = widget.initialData;
    if (data != null)
      _select(data.exercises, data.defaults, _selectedIndex(data.exercises));
    _stream = _watchData(widget.initialStream);
  }

  Stream<StartPlanData> _watchData([Stream<StartPlanData>? source]) =>
      (source ?? watchStartPlanData(db, widget.plan.id)).map((data) {
        if (!mounted) return data;
        if (data.plan == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        }
        _select(data.exercises, data.defaults, _selectedIndex(data.exercises));
        return data;
      });

  void _reloadDatabaseStreams() {
    if (mounted) setState(() => _stream = _watchData());
  }

  String _displayTitle(BuildContext context, Plan plan) {
    if (plan.title?.isNotEmpty == true) return plan.title!;
    return plan.days
        .split(',')
        .where((day) => day.trim().isNotEmpty)
        .map((day) => localizedWeekday(context.l10n, day.trim()))
        .join(', ');
  }

  void _fillPreviousSet(ExerciseSetView previous) {
    setState(() {
      _unit = previous.unit;
      _input.fill(previous);
    });
  }

  void _update(ExerciseSetView exerciseSet) {
    final settings = context.read<Setting>();
    _unit = exerciseSet.cardio && settings.cardioUnit != 'last-entry'
        ? settings.cardioUnit
        : exerciseSet.unit;

    _input.fill(exerciseSet);
    _notes.text = exerciseSet.notes ?? "";
  }

  Future<void> _save(StartPlanData? data, int selected) async {
    if (data == null) return;
    final exercises = data.exercises;
    if (_saving) return;
    _saving = true;
    try {
      if (!_key.currentState!.validate()) return;
      if (exercises.isEmpty) return;
      if (selected >= exercises.length) return;

      final workout = data.workout;
      if (!mounted) return;

      final entry = exercises[selected];
      final exerciseId = entry.exercise.id;
      final exercise = entry.exercise.name;
      final restMs = entry.exercise.defaultRestDurationMs;
      final draft = _input.apply(
        context,
        ExerciseSetView(
          cardio: entry.exercise.kind == 'cardio',
          category: data.categories[exerciseId],
          created: DateTime.now().toLocal(),
          image: entry.exercise.image,
          name: exercise,
          notes: _notes.text,
          planId: widget.plan.id,
          restMs: restMs,
          unit: _unit,
        ),
      );
      double? bodyWeight;
      double? bodyWeightKg;
      final settings = context.read<Setting>();
      final timerState = context.read<TimerState>();
      if (settings.showBodyWeight) {
        final weightEntry = await getLatestBodyWeight(db);
        if (weightEntry != null) {
          bodyWeightKg = weightEntry.weightKg;
          bodyWeight = displayLoad(draft.unit, weightEntry.weightKg);
        }
      }
      if (settings.showBodyWeight && bodyWeight == null) {
        final lastSet = await ExerciseSetQuery(
          db,
          exerciseName: exercise,
        ).firstOrNull();
        bodyWeight = lastSet?.bodyWeight;
      }

      if (settings.notifications && !settings.notificationPermissionRequested) {
        await requestNotificationPermission();
      }

      if (!settings.explainedPermissions &&
          settings.restTimers &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          mounted) {
        await Navigator.of(
          context,
        ).push(FlexPageRoute(builder: (context) => const PermissionsPage()));
      }

      if (!mounted) return;
      final max = entry.planExercise.maxSets;
      final warmupSets = entry.planExercise.warmupSets ?? 0;
      final peTimers = entry.planExercise.timers;

      final count = (data.sets[exerciseId]?.length ?? 0) + 1;

      if (settings.restTimers && count > warmupSets && peTimers) {
        timerState.startRestTimer(
          "$exercise ($count/${max ?? settings.maxSets})",
          settings,
          durationMs: restMs,
          target: "plan:${widget.plan.id}",
        );
      }

      final finished =
          count == (max ?? settings.maxSets) && selected < exercises.length - 1;

      final exerciseSet = await insertExerciseSet(
        db,
        exerciseSet: draft.copyWith(
          bodyWeight: bodyWeight,
          created: DateTime.now().toLocal(),
        ),
        exerciseId: exerciseId,
        workoutId: workout.id,
        bodyWeightKg: bodyWeightKg,
      );
      if (!mounted) return;
      final messages = positiveReinforcementMessages(context.l10n);
      _lastSavedAt = DateTime.now();
      if (_selectedExerciseId == exerciseId) {
        setState(() {
          _update(exerciseSet);
          if (finished) _select(exercises, data.defaults, selected + 1);
        });
      }

      if (!settings.notifications) return;

      final best = await isBestExerciseSet(db, exerciseSet);
      if (!best) return;

      final random = Random();
      final randomMessage = messages[random.nextInt(messages.length)];
      if (mounted && random.nextDouble() < 0.3) showAppMessage(randomMessage);
    } finally {
      _saving = false;
    }
  }

  void _select(
    List<PlanExerciseEntry> exercises,
    Map<int, ExerciseSetView>? defaults,
    int index,
  ) {
    if (exercises.isEmpty) {
      _selectedExerciseId = null;
      _clear();
      return;
    }
    final selected = index.clamp(0, exercises.length - 1);
    final exercise = exercises[selected].exercise;
    if (_selectedExerciseId == exercise.id) return;
    _selectedExerciseId = exercise.id;
    final previous = defaults?[exercise.id];
    if (previous != null) {
      _update(previous);
    } else {
      _clear();
      final settings = context.read<Setting>();
      _unit =
          exercise.kind == 'strength' && settings.strengthUnit != 'last-entry'
          ? settings.strengthUnit
          : exercise.displayUnit;
    }
  }

  void _clear() {
    final settings = context.read<Setting>();
    _unit = settings.strengthUnit == 'last-entry'
        ? 'kg'
        : settings.strengthUnit;
    _input.clear();
    _notes.text = '';
  }

  void useBodyWeight() async {
    final weightSet = await getLatestBodyWeight(db);
    if (!mounted) return;
    if (weightSet == null) {
      showAppMessage(context.l10n.noWeightEnteredYet);
      return;
    }
    _input.weight.text = toString(displayLoad(_unit, weightSet.weightKg));
  }
}
