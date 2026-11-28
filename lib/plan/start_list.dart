import 'package:drift/drift.dart' hide Column;
import 'package:flex/bottom_nav.dart';
import 'package:flex/constants.dart';
import 'package:flex/custom_set_indicator.dart';
import 'package:flex/database/database.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/exercise_modal.dart';
import 'package:flex/plan/plan_progress.dart';
import 'package:flex/plan/workout_sessions.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StartList extends StatefulWidget {
  final List<PlanExerciseEntry> exercises;
  final int selected;
  final Future<void> Function(int) onSelect;
  final Map<int, List<ExerciseSetView>> sets;
  final int? workoutId;

  const StartList({
    super.key,
    required this.exercises,
    required this.selected,
    required this.onSelect,
    required this.sets,
    required this.workoutId,
  });

  @override
  State<StartList> createState() => _StartListState();
}

typedef Tapped = ({int index, DateTime dateTime});

class _StartListState extends State<StartList> {
  // bottomNavHeight clears the FAB; the extra 80 clears the SessionSets
  // chip row that renders above this list on the currently selected
  // exercise.
  static const _bottomPadding = bottomNavHeight + 80.0;

  Tapped lastTap = (index: 0, dateTime: DateTime(0));

  void tap(int index) {
    widget.onSelect(index);
    final exerciseSet =
        widget.sets[widget.exercises[index].exercise.id]?.lastOrNull;
    if (exerciseSet == null) return;

    final now = DateTime.now();
    if (now.difference(lastTap.dateTime) >= const Duration(milliseconds: 300) ||
        index != lastTap.index) {
      lastTap = (index: index, dateTime: now);
      return;
    }

    Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => EditSetPage(exerciseSet: exerciseSet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final max = context.select<Setting, int>((settings) => settings.maxSets);
    final trailing = context.select<Setting, PlanTrailing>(
      (settings) => PlanTrailing.values.byName(
        settings.planTrailing.replaceFirst('PlanTrailing.', ''),
      ),
    );
    final desktop = isDesktopLayout(context);
    final padding = EdgeInsets.only(bottom: desktop ? 0 : _bottomPadding);

    Widget list(double? width) {
      Widget item(BuildContext context, int index) =>
          itemBuilder(context, index, max, trailing, width);

      if (trailing == PlanTrailing.reorder) {
        return ReorderableListView.builder(
          shrinkWrap: desktop,
          itemCount: widget.exercises.length,
          buildDefaultDragHandles: !desktop,
          padding: padding,
          itemBuilder: item,
          onReorderItem: (oldIndex, newIndex) async {
            final ordered = widget.exercises.toList();
            final entry = ordered.removeAt(oldIndex);
            ordered.insert(newIndex, entry);

            await db.batch((batch) {
              for (var i = 0; i < ordered.length; i++) {
                batch.update(
                  db.planExercises,
                  PlanExercisesCompanion(sequence: Value(i)),
                  where: (pe) => pe.id.equals(ordered[i].planExercise.id),
                );
              }
            });
          },
        );
      }
      if (desktop) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.exercises.length; i++)
                item(context, i),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: padding,
        itemCount: widget.exercises.length,
        itemBuilder: item,
      );
    }

    return desktop
        ? LayoutBuilder(builder: (_, constraints) => list(constraints.maxWidth))
        : list(null);
  }

  Widget itemBuilder(
    BuildContext context,
    int index,
    int maxSets,
    PlanTrailing trailing,
    double? width,
  ) {
    final exercise = widget.exercises[index];
    final count = widget.sets[exercise.exercise.id]?.length ?? 0;
    final max = exercise.planExercise.maxSets ?? maxSets;

    final desktop = width != null;
    final compact = desktop && width < 260;
    final showProgress = desktop && width >= 420;
    final trail = switch (trailing) {
      PlanTrailing.reorder => ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle, size: 32),
      ),
      PlanTrailing.none => const SizedBox(),
      _ => Text(
        planProgressLabel(context, trailing, count, max),
        style: const TextStyle(fontSize: 16),
      ),
    };

    final colors = Theme.of(context).colorScheme;
    final selected = index == widget.selected;

    Widget actions({bool inline = false}) => ExerciseModal(
      key: ValueKey(exercise.planExercise.id),
      planExercise: exercise.planExercise,
      exerciseName: exercise.exercise.name,
      workoutId: widget.workoutId,
      hasData: count > 0,
      onSelect: () {
        if (mounted) widget.onSelect(index);
      },
      inlineActions: inline,
    );
    Future<void> showActions() => showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      builder: (_) => SafeArea(child: actions()),
    );

    final content = desktop
        ? Padding(
            key: Key(exercise.exercise.name),
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : 4,
              bottom: index == widget.exercises.length - 1 ? 0 : 4,
            ),
            child: Material(
              color: selected
                  ? colors.primary.withValues(alpha: .12)
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.none,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => tap(index),
                onLongPress: null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (!compact) ...[
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              exercise.exercise.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (!compact) const SizedBox(width: 12),
                          if (showProgress) ...[
                            SizedBox(
                              width: 150,
                              child: CustomSetIndicator(count: count, max: max),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (!compact &&
                              (trailing == PlanTrailing.reorder ||
                                  trailing == PlanTrailing.none)) ...[
                            Text(
                              planProgressLabel(
                                context,
                                PlanTrailing.ratio,
                                count,
                                max,
                              ),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(width: 10),
                          ],
                          trail,
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: actions(inline: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ListTile(
                onTap: () => tap(index),
                trailing: trail,
                title: Row(
                  children: [
                    RadioGroup<bool>(
                      groupValue: true,
                      onChanged: (value) {
                        widget.onSelect(index);
                      },
                      child: Radio<bool>(value: selected),
                    ),
                    Flexible(child: Text(exercise.exercise.name)),
                  ],
                ),
              ),
              CustomSetIndicator(count: count, max: max),
            ],
          );

    if (desktop) return content;
    return GestureDetector(
      key: Key(exercise.exercise.name),
      onLongPress: showActions,
      child: content,
    );
  }
}
