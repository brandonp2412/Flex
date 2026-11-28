import 'package:drift/drift.dart' as drift;
import 'package:flex/search_list_scaffold.dart';
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
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class PlansPageWidget extends StatefulWidget {
  final GlobalKey<NavigatorState> navKey;

  const PlansPageWidget({super.key, required this.navKey});

  @override
  State<PlansPageWidget> createState() => _PlansPageWidgetState();
}

class _PlansPageWidgetState extends State<PlansPageWidget> {
  final _searchController = TextEditingController();
  String get _search => _searchController.text;
  late Stream<List<PlanOverview>> _plansStream;
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
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _createStreams() {
    _plansStream = watchPlanOverviews(db);
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
    return StreamBuilder<List<PlanOverview>>(
      stream: _plansStream,
      builder: (context, plansSnapshot) =>
          StreamBuilder<List<PlanExerciseEntry>>(
            stream: _exerciseStream,
            builder: (context, exercisesSnapshot) {
              final overviews = plansSnapshot.data ?? const <PlanOverview>[];
              final plans = [for (final overview in overviews) overview.plan];
              final exercises = exercisesSnapshot.data;
              final filtered = _filterPlans(
                plans,
                exercises ?? const <PlanExerciseEntry>[],
              );

              return SearchListScaffold(
                title: context.l10n.navPlans,
                addLabel: context.l10n.newPlan,
                onAdd: _addPlan,
                showAdd: !plansSnapshot.hasData || filtered.isNotEmpty,
                scroll: _scroll,
                body: plansSnapshot.hasError || exercisesSnapshot.hasError
                    ? const AppErrorState()
                    : searchListBody(
                        list: PlansList(
                          scroll: _scroll,
                          plans: plansSnapshot.hasData ? filtered : null,
                          exercises: exercises,
                          countsByPlan: {
                            for (final overview in overviews)
                              overview.plan.id: overview.count,
                          },
                          navKey: widget.navKey,
                          selected: _selection,
                          search: _search,
                          onSelect: (id) {
                            setState(() {
                              if (!_selection.remove(id)) _selection.add(id);
                            });
                          },
                        ),
                        search: AppSearch(
                          hintText: context.l10n.searchPlans,
                          controller: _selection,
                          onShare: () async {
                            final l10n = context.l10n;
                            final selectedPlans = plans
                                .where((plan) => _selection.contains(plan.id))
                                .toList();

                            final byPlan = groupEnabledPlanExercisesByPlan(
                              exercises ?? const [],
                            );
                            final summaries = selectedPlans.map((plan) {
                              final days = plan.days
                                  .split(',')
                                  .where((day) => day.isNotEmpty)
                                  .map((day) => localizedWeekday(l10n, day))
                                  .join(', ');
                              final summary =
                                  (byPlan[plan.id] ??
                                          const <PlanExerciseEntry>[])
                                      .map(
                                        (entry) => '- ${entry.exercise.name}',
                                      )
                                      .join('\n');
                              return '$days:\n$summary';
                            });

                            await SharePlus.instance.share(
                              ShareParams(text: summaries.join('\n\n')),
                            );
                            if (mounted) setState(_selection.clear);
                          },
                          textController: _searchController,
                          onChange: (_) => setState(() {}),
                          onClearSelection: () => setState(() {}),

                          onDelete: () async {
                            final selectedIds = _selection.toList();
                            setState(_selection.clear);
                            await db.transaction(() async {
                              await db.planExercises.deleteWhere(
                                (tbl) => tbl.planId.isIn(selectedIds),
                              );
                              await db.plans.deleteWhere(
                                (tbl) => tbl.id.isIn(selectedIds),
                              );
                            });
                          },
                          onSelectAll: () => setState(() {
                            _selection.addAll(filtered.map((plan) => plan.id));
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
                                builder: (context) => EditPlanPage(plan: plan),
                              ),
                            );
                          },
                        ),
                      ),
              );
            },
          ),
    );
  }
}
