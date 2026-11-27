import 'package:drift/drift.dart' as drift;
import 'package:flex/app_search.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/edit_plan_page.dart';
import 'package:flex/plan/plan_queries.dart';
import 'package:flex/plan/plan_tile.dart';
import 'package:flex/plan/workout_sessions.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PlansList extends StatelessWidget {
  final List<Plan>? plans;
  final List<PlanExerciseEntry>? exercises;
  final GlobalKey<NavigatorState> navKey;
  final Set<int> selected;
  final Function(int) onSelect;
  final String search;
  final ScrollController scroll;
  final Map<int, PlanCount> countsByPlan;

  const PlansList({
    super.key,
    required this.plans,
    required this.exercises,
    required this.navKey,
    required this.selected,
    required this.onSelect,
    required this.search,
    required this.scroll,
    this.countsByPlan = const {},
  });

  @override
  Widget build(BuildContext context) {
    final searchLabel = search.trim();
    final noneFound = Padding(
      padding: const EdgeInsets.only(top: appSearchHeight),
      child: AppEmptyState(
        icon: searchLabel.isEmpty
            ? Icons.fitness_center_rounded
            : Icons.search_off_rounded,
        title: searchLabel.isEmpty
            ? context.l10n.noPlansYet
            : context.l10n.noMatchingPlans,
        message: searchLabel.isEmpty
            ? context.l10n.createFirstTrainingPlan
            : context.l10n.nothingMatchesPlanSearch(searchLabel),
        actionLabel: searchLabel.isEmpty
            ? context.l10n.createPlan
            : context.l10n.createNamedPlan(searchLabel),
        actionIcon: Icons.add_rounded,
        onAction: () async {
          final plan = PlansCompanion(
            days: const drift.Value(''),
            title: drift.Value(searchLabel),
          );
          if (context.mounted)
            await Navigator.of(context).push(
              FlexPageRoute(builder: (context) => EditPlanPage(plan: plan)),
            );
        },
      ),
    );

    if (plans == null || exercises == null) {
      return const SizedBox.shrink();
    }

    final weekday = weekdays[DateTime.now().weekday - 1];
    final filteredPlans = plans!.toList();
    if (filteredPlans.isEmpty) return noneFound;
    final exercisesByPlan = groupEnabledPlanExercisesByPlan(exercises!);
    final reorder =
        context.read<Setting>().planTrailing == PlanTrailing.reorder.toString();
    final padding = EdgeInsets.only(
      bottom: isDesktopLayout(context) ? 32 : fabListPadding,
      top: appSearchHeight + 8,
    );

    Widget item(BuildContext context, int index) {
      final plan = filteredPlans[index];
      return ResponsiveContent(
        key: reorder ? Key(plan.id.toString()) : null,
        child: PlanTile(
          plan: plan,
          exercises: exercisesByPlan[plan.id] ?? const <PlanExerciseEntry>[],
          weekday: weekday,
          index: index,
          navigatorKey: navKey,
          selected: selected,
          count: countsByPlan[plan.id],
          onSelect: onSelect,
        ),
      );
    }

    if (reorder)
      return ReorderableListView.builder(
        scrollController: scroll,
        buildDefaultDragHandles: !isDesktopLayout(context),
        itemCount: filteredPlans.length,
        padding: padding,
        itemBuilder: item,
        onReorderItem: (int old, int idx) async {
          final temp = filteredPlans[old];
          filteredPlans.removeAt(old);
          filteredPlans.insert(idx, temp);

          await db.transaction(() async {
            for (int i = 0; i < filteredPlans.length; i++) {
              final plan = filteredPlans[i];
              final updated = plan
                  .toCompanion(false)
                  .copyWith(sequence: drift.Value(i));
              await db.update(db.plans).replace(updated);
            }
          });
        },
      );

    return ListView.builder(
      controller: scroll,
      itemCount: filteredPlans.length,
      padding: padding,
      itemBuilder: item,
    );
  }
}
