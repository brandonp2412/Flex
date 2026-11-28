import 'package:flex/exercise_summary_tile.dart';
import 'package:flex/selection_tile.dart';

import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/graph/exercise_graph_page.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/set_summary.dart';
import 'package:flutter/material.dart';

class GraphTile extends StatelessWidget {
  final GraphExerciseSummary exerciseSet;
  final Set<String> selected;
  final Function(String) onSelect;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;

  const GraphTile({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.exerciseSet,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = formatSetSummary(
      context,
      unitCode: exerciseSet.unit,
      cardio: exerciseSet.cardio,
      weight: exerciseSet.weight,
      reps: exerciseSet.reps,
      distance: exerciseSet.distance,
      duration: exerciseSet.duration,
      bodyWeight: exerciseSet.bodyWeight,
    );
    return ExerciseSummaryTile(
      name: exerciseSet.name,
      summary: trailing,
      created: exerciseSet.created,
      image: exerciseSet.image?.isNotEmpty == true ? exerciseSet.image : null,
      emptyLabel: exerciseSet.hasData ? null : context.l10n.noDataYet,
      graph: true,
      selected: selected.contains(exerciseSet.selectionKey),
      selectionActive: selected.isNotEmpty,
      onSelect: () => onSelect(exerciseSet.selectionKey),
      onOpen: () {
        Navigator.of(context).push(
          FlexPageRoute(
            builder: (context) => ExerciseGraphPage(
              initialName: exerciseSet.name,
              initialUnit: exerciseSet.unit,
              cardio: exerciseSet.cardio && !exerciseSet.bodyWeight,
              bodyWeight: exerciseSet.bodyWeight,
            ),
          ),
        );
      },
      onSecondaryTapDown: (details) async {
        final action = await showEditDeleteMenu(
          context,
          details.globalPosition,
          edit: onEdit != null,
          delete: onDelete != null,
        );
        if (!context.mounted) return;
        switch (action) {
          case EditDeleteAction.edit:
            onEdit?.call();
          case EditDeleteAction.delete:
            await onDelete?.call();
          case null:
            break;
        }
      },
    );
  }
}
