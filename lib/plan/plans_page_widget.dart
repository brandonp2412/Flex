import 'package:drift/drift.dart' as drift;
import 'package:flex/app_fab.dart';
import 'package:flex/app_search.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/error_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/edit_plan_page.dart';
import 'package:flex/plan/plan_queries.dart';
import 'package:flex/plan/plans_list.dart';
import 'package:flex/plan/workout_sessions.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class PlansPageWidget extends StatefulWidget {
  final GlobalKey<NavigatorState> navKey;

  const PlansPageWidget({super.key, required this.navKey});

  @override
  State<PlansPageWidget> createState() => _PlansPageWidgetState();
}

class _PlansPageWidgetState extends State<PlansPageWidget> {
  String _search = '';
  late Stream<List<Plan>> _plansStream;
  late Stream<List<PlanExerciseEntry>> _exerciseStream;

  final _selection = <int>{};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _createStreams();
    dbVersion.addListener(_onDatabaseChanged);
  }

  @override
  void dispose() {
    dbVersion.removeListener(_onDatabaseChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _createStreams() {
    _plansStream = watchPlans();
    _exerciseStream = watchAllPlanExerciseEntries(db);
  }

  void _onDatabaseChanged() {
    if (!mounted) return;
    setState(_createStreams);
  }

  List<Plan> _filterPlans(List<Plan> plans, List<PlanExerciseEntry> exercises) {
    final l10n = context.l10n;
    return filterPlans(
      plans,
      exercises,
      _search,
      (day) => localizedWeekday(l10n, day),
    );
  }

  Future<void> _addPlan() async {
    const plan = PlansCompanion(days: drift.Value(''));
    await Navigator.of(
      context,
    ).push(FlexPageRoute(builder: (context) => const EditPlanPage(plan: plan)));
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);

    return StreamBuilder<List<Plan>>(
      stream: _plansStream,
      builder: (context, plansSnapshot) =>
          StreamBuilder<List<PlanExerciseEntry>>(
            stream: _exerciseStream,
            builder: (context, exercisesSnapshot) {
              final plans = plansSnapshot.data ?? const <Plan>[];
              final exercises = exercisesSnapshot.data;
              final filtered = _filterPlans(
                plans,
                exercises ?? const <PlanExerciseEntry>[],
              );

              return Scaffold(
                floatingActionButtonAnimator:
                    FloatingActionButtonAnimator.noAnimation,
                resizeToAvoidBottomInset: false,
                appBar: desktop
                    ? AppBar(
                        title: Text(context.l10n.navPlans),
                        actions: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: FilledButton.icon(
                              onPressed: _addPlan,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(context.l10n.newPlan),
                            ),
                          ),
                        ],
                      )
                    : null,
                body: plansSnapshot.hasError || exercisesSnapshot.hasError
                    ? const AppErrorState()
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: PlansList(
                              scroll: _scroll,
                              plans: plansSnapshot.hasData ? filtered : null,
                              exercises: exercises,
                              navKey: widget.navKey,
                              selected: _selection,
                              search: _search,
                              onSelect: (id) {
                                setState(() {
                                  if (!_selection.remove(id))
                                    _selection.add(id);
                                });
                              },
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: AppSearch(
                              hintText: context.l10n.searchPlans,
                              controller: _selection,
                              onShare: () async {
                                final l10n = context.l10n;
                                final selectedPlans = plans
                                    .where(
                                      (plan) => _selection.contains(plan.id),
                                    )
                                    .toList();

                                final summaries = await Future.wait(
                                  selectedPlans.map((plan) async {
                                    final days = plan.days
                                        .split(',')
                                        .where((day) => day.isNotEmpty)
                                        .map(
                                          (day) => localizedWeekday(l10n, day),
                                        )
                                        .join(', ');
                                    final planExercises =
                                        await getPlanExerciseEntries(
                                          db,
                                          plan.id,
                                        );
                                    final summary = planExercises
                                        .map(
                                          (entry) => '- ${entry.exercise.name}',
                                        )
                                        .join('\n');
                                    return '$days:\n$summary';
                                  }),
                                );

                                await SharePlus.instance.share(
                                  ShareParams(text: summaries.join('\n\n')),
                                );
                                if (mounted) setState(_selection.clear);
                              },
                              onChange: (value) =>
                                  setState(() => _search = value),
                              onDelete: () async {
                                final selectedIds = _selection.toList();
                                setState(_selection.clear);
                                await db.planExercises.deleteWhere(
                                  (tbl) => tbl.planId.isIn(selectedIds),
                                );
                                await db.plans.deleteWhere(
                                  (tbl) => tbl.id.isIn(selectedIds),
                                );
                              },
                              onSelectAll: () => setState(() {
                                _selection.addAll(
                                  filtered.map((plan) => plan.id),
                                );
                              }),
                              onEdit: () async {
                                final plan = plans
                                    .firstWhere(
                                      (plan) => plan.id == _selection.first,
                                    )
                                    .toCompanion(false);
                                if (!context.mounted) return;
                                await Navigator.of(context).push(
                                  FlexPageRoute(
                                    builder: (context) =>
                                        EditPlanPage(plan: plan),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                floatingActionButton: desktop
                    ? null
                    : AppFab(
                        onPressed: _addPlan,
                        label: Text(context.l10n.actionAdd),
                        icon: const Icon(Icons.add),
                        scroll: _scroll,
                      ),
              );
            },
          ),
    );
  }
}
