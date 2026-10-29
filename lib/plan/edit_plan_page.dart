import 'package:drift/drift.dart' hide Column;
import 'package:flex/app_fab.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/day_selector.dart';
import 'package:flex/editor_content.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/error_state.dart';
import 'package:flex/graph/add_exercise_page.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/logging.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/exercise_tile.dart';
import 'package:flex/plan/plan_queries.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/unsaved_changes.dart';
import 'package:flutter/material.dart';

class EditPlanPage extends StatefulWidget {
  final PlansCompanion plan;

  const EditPlanPage({required this.plan, super.key});

  @override
  createState() => _EditPlanPageState();
}

class _EditPlanPageState extends State<EditPlanPage>
    with UnsavedChanges<EditPlanPage> {
  List<bool> _days = [];
  List<PlanExerciseDraft> _exercises = [];
  bool _loading = true;
  bool _loadError = false;
  String _search = '';

  final _node = FocusNode();
  final _searchCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  Future<void> addExercise() async {
    Exercise? exercise = await Navigator.of(
      context,
    ).push(FlexPageRoute(builder: (context) => AddExercisePage(name: _search)));
    if (exercise == null || !mounted) return;

    setState(() {
      _exercises.add(
        PlanExerciseDraft(
          exerciseName: exercise.name,
          planExercise: PlanExercisesCompanion(
            exerciseId: Value(exercise.id),
            enabled: const Value(true),
          ),
        ),
      );
      _exercises.sort((a, b) {
        if (a.planExercise.enabled.value != b.planExercise.enabled.value) {
          return b.planExercise.enabled.value ? 1 : -1;
        }
        return a.exerciseName.compareTo(b.exerciseName);
      });
      _search = '';
      dirty = true;
    });
    _searchCtrl.text = '';
  }

  @override
  Widget build(BuildContext context) {
    final storedDays = widget.plan.days.value
        .split(',')
        .where((day) => day.isNotEmpty);
    final title = storedDays.isEmpty
        ? context.l10n.addPlan
        : storedDays
              .map((day) => localizedWeekday(context.l10n, day))
              .join(', ');

    final exercises = filterPlanExerciseDrafts(_exercises, _search);
    final desktop = isDesktopLayout(context);
    final colors = Theme.of(context).colorScheme;

    return guardUnsavedChanges(
      child: Scaffold(
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(title)),
        body: EditorContent(
          maxWidth: 1040,
          child: ListView(
            padding: editorListPadding(context, hasFab: !desktop),
            children: [
              if (desktop)
                Text(
                  context.l10n.planDetails,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              if (desktop) const SizedBox(height: 12),
              Container(
                padding: desktop ? const EdgeInsets.all(20) : EdgeInsets.zero,
                decoration: desktop
                    ? BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: context.l10n.titleOptional,
                      ),
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => markDirty(),
                    ),
                    const SizedBox(height: 16),
                    DaySelector(daySwitches: _days, onChanged: markDirty),
                  ],
                ),
              ),
              SizedBox(height: desktop ? 24 : 8),
              if (desktop)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.l10n.exercisesLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              SearchBar(
                controller: _searchCtrl,
                focusNode: _node,
                onTap: () => _node.requestFocus(),
                leading: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.search),
                ),
                textCapitalization: TextCapitalization.sentences,
                hintText: context.l10n.searchExercises,
                onChanged: (value) => setState(() {
                  _search = value;
                }),
              ),
              const SizedBox(height: 10),
              Material(
                color: desktop
                    ? colors.surfaceContainerLow
                    : Colors.transparent,
                borderRadius: desktop ? BorderRadius.circular(14) : null,
                child: ListTile(
                  leading: IconButton(
                    tooltip: context.l10n.addExercise,
                    icon: const Icon(Icons.add_rounded),
                    onPressed: addExercise,
                  ),
                  title: Text(
                    _search.isEmpty
                        ? context.l10n.addExercise
                        : context.l10n.addNamed(_search),
                  ),
                  trailing: desktop
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                  onTap: addExercise,
                ),
              ),
              const SizedBox(height: 6),
              if (_loadError)
                const SizedBox(height: 260, child: AppErrorState())
              else if (_loading)
                const SizedBox.shrink()
              else if (exercises.isEmpty)
                SizedBox(
                  height: 260,
                  child: AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.l10n.noExercisesFound,
                    message: _search.isEmpty
                        ? context.l10n.addExerciseToPlan
                        : context.l10n.nothingMatchesExerciseSearch(_search),
                    actionLabel: _search.isEmpty
                        ? context.l10n.addExercise
                        : context.l10n.addNamed(_search),
                    actionIcon: Icons.add_rounded,
                    onAction: addExercise,
                  ),
                )
              else
                for (final pe in exercises)
                  ExerciseTile(
                    planExercise: pe.planExercise,
                    exerciseName: pe.exerciseName,
                    onChange: (value) {
                      final id = _exercises.indexWhere(
                        (exercise) =>
                            exercise.planExercise.exerciseId.value ==
                            pe.planExercise.exerciseId.value,
                      );
                      if (id == -1) return;
                      setState(() {
                        _exercises[id] = pe.copyWithPlanExercise(value);
                        dirty = true;
                      });
                    },
                  ),
              if (desktop) ...[
                const SizedBox(height: 24),
                DesktopEditorSaveButton(onPressed: save),
              ],
            ],
          ),
        ),
        floatingActionButton: desktop
            ? null
            : AppFab(
                onPressed: save,
                label: Text(context.l10n.actionSave),
                icon: const Icon(Icons.save),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _node.dispose();
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _titleCtrl.text = widget.plan.title.value ?? '';
    final list = widget.plan.days.value.split(',');
    _days = weekdays.map((day) => list.contains(day)).toList();
    if (widget.plan.id.present) {
      _loadExercises();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadExercises();
      });
    }
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await loadPlanExerciseDrafts(widget.plan);
      if (!mounted) return;
      setState(() {
        _exercises = exercises;
        _loading = false;
        _loadError = false;
      });
    } catch (error, stackTrace) {
      talker.handle(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Iterable<PlanExercisesCompanion> _orderedExercises(int planId) sync* {
    var sequence = 0;
    for (final draft in _exercises) {
      if (!draft.planExercise.enabled.value) continue;
      yield draft.planExercise.copyWith(
        planId: Value(planId),
        sequence: Value(sequence++),
      );
    }
    for (final draft in _exercises) {
      if (draft.planExercise.enabled.value) continue;
      yield draft.planExercise.copyWith(
        planId: Value(planId),
        sequence: Value(sequence++),
      );
    }
  }

  Future<void> save() async {
    final selected = [];
    for (int i = 0; i < _days.length; i++)
      if (_days[i]) selected.add(weekdays[i]);

    if (selected.isEmpty && _titleCtrl.text.isEmpty) {
      messengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(context.l10n.selectDays),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          duration: const Duration(seconds: 4),
          persist: false,
        ),
      );
      return;
    }

    if (_exercises.where((draft) => draft.planExercise.enabled.value).isEmpty) {
      messengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(context.l10n.selectExercises),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          duration: const Duration(seconds: 4),
          persist: false,
        ),
      );
      return;
    }

    var newPlan = PlansCompanion.insert(
      days: selected.join(','),
      title: Value(_titleCtrl.text),
    );

    if (widget.plan.id.present) {
      final planId = widget.plan.id.value;
      await db.transaction(() async {
        await (db.update(
          db.plans,
        )..where((plan) => plan.id.equals(planId))).write(
          PlansCompanion(
            days: Value(selected.join(',')),
            title: Value(_titleCtrl.text),
          ),
        );

        for (final exercise in _orderedExercises(planId)) {
          if (exercise.id.present) {
            await (db.update(db.planExercises)
                  ..where((row) => row.id.equals(exercise.id.value)))
                .write(exercise);
          } else {
            await db.into(db.planExercises).insert(exercise);
          }
        }
      });
    } else {
      final highest =
          await (db.plans.select()
                ..orderBy([(u) => OrderingTerm.desc(u.sequence)])
                ..limit(1))
              .getSingleOrNull();
      final sequence = (highest?.sequence ?? 0) + 1;
      newPlan = newPlan.copyWith(sequence: Value(sequence));

      final id = await db.into(db.plans).insert(newPlan);
      await db.planExercises.insertAll(
        _orderedExercises(
          id,
        ).where((exercise) => exercise.enabled.value).toList(),
      );
    }

    talker.info(
      widget.plan.id.present ? 'Updated workout plan' : 'Created workout plan',
    );

    if (!mounted) return;
    allowPop = true;
    Navigator.pop(context);
  }
}
