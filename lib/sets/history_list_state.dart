import 'package:flex/exercise_summary_tile.dart';
import 'package:flex/database/database.dart';
import 'package:flex/app_confirmation.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/selection_tile.dart';
import 'package:flex/set_summary.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/weight_page.dart';
import 'package:flutter/material.dart';

abstract class HistoryListState<T extends StatefulWidget> extends State<T> {
  ScrollController get scroll;
  Function get onNext;
  Set<int> get selected;
  void select(int id);
  bool get bodyWeight => false;
  Future<void> Function()? get onChanged => null;
  bool _goingNext = false;

  @override
  void initState() {
    super.initState();
    scroll.addListener(scrollListener);
  }

  @override
  void dispose() {
    scroll.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    if (scroll.position.pixels < scroll.position.maxScrollExtent - 200 ||
        _goingNext)
      return;
    _goingNext = true;
    onNext();
    setState(() => _goingNext = false);
  }

  Future<void> editEntry(ExerciseSetView exerciseSet) async {
    if (bodyWeight) {
      final weight = await getBodyWeightById(db, exerciseSet.id);
      if (!mounted || weight == null) return;
      await Navigator.of(
        context,
      ).push(FlexPageRoute(builder: (context) => WeightPage(initial: weight)));
    } else {
      await Navigator.of(context).push(
        FlexPageRoute(
          builder: (context) => EditSetPage(exerciseSet: exerciseSet),
        ),
      );
    }
    if (mounted) await onChanged?.call();
  }

  Future<void> showContextMenu(
    BuildContext context,
    TapDownDetails details,
    ExerciseSetView exerciseSet,
  ) async {
    final action = await showEditDeleteMenu(context, details.globalPosition);
    if (!context.mounted) return;
    switch (action) {
      case EditDeleteAction.edit:
        await editEntry(exerciseSet);
      case EditDeleteAction.delete:
        final confirmed = await showAppConfirmation(
          context,
          title: context.l10n.confirmDelete,
          message: context.l10n.deleteSetConfirmation(exerciseSet.name),
          actionLabel: context.l10n.actionDelete,
          destructive: true,
        );
        if (confirmed == true) {
          if (bodyWeight) {
            await deleteBodyWeight(db, exerciseSet.id);
          } else {
            await deleteExerciseSets(db, [exerciseSet.id]);
          }
          if (mounted) await onChanged?.call();
        }
      case null:
        break;
    }
  }

  Widget entryTile(
    BuildContext context,
    ExerciseSetView set, {
    bool grouped = false,
    bool showTime = false,
  }) => ExerciseSummaryTile(
    name: set.name,
    summary: formatSetSummary(
      context,
      unitCode: set.unit,
      cardio: set.cardio,
      weight: set.weight,
      reps: set.reps,
      distance: set.distance,
      duration: set.duration,
      incline: set.incline,
      bodyWeight: bodyWeight,
    ),
    created: set.created,
    image: set.image,
    selected: selected.contains(set.id),
    selectionActive: selected.isNotEmpty,
    onSelect: () => select(set.id),
    onOpen: () => editEntry(set),
    onSecondaryTapDown: (details) => showContextMenu(context, details, set),
    showTime: showTime,
    grouped: grouped,
    desktopPadding: grouped
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 5)
        : const EdgeInsets.all(4),
  );
}
