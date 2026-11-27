import 'package:flex/exercise_avatar.dart';

import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/graph/exercise_graph_page.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/set_summary.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _GraphContextAction { edit, delete }

class GraphTile extends StatelessWidget {
  final GraphExerciseSummary exerciseSet;
  final Set<String> selected;
  final Function(String) onSelect;
  final TabController tabCtrl;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;

  const GraphTile({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.exerciseSet,
    required this.tabCtrl,
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
    final showImages = context.select<Setting, bool>(
      (settings) => settings.showImages,
    );

    final leading = showImages
        ? ExerciseAvatar(
            name: exerciseSet.name,
            image: exerciseSet.image?.isNotEmpty == true
                ? exerciseSet.image
                : null,
            onTap: () => onSelect(exerciseSet.selectionKey),
          )
        : null;

    final desktop = isDesktopLayout(context);
    final colors = Theme.of(context).colorScheme;
    final tile = Material(
      color: switch (desktop) {
        _ when selected.contains(exerciseSet.selectionKey) =>
          colors.primary.withValues(alpha: .18),
        true => colors.surfaceContainerLow,
        _ => Colors.transparent,
      },
      borderRadius: desktop ? BorderRadius.circular(16) : null,
      clipBehavior: desktop ? Clip.antiAlias : Clip.none,
      child: ListTile(
        contentPadding: desktop
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 9)
            : null,
        leading: leading,
        title: Text(
          exerciseSet.name,
          style: desktop
              ? Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
              : null,
        ),
        subtitle: Selector<Setting, String>(
          selector: (context, settings) => settings.longDateFormat,
          builder: (context, dateFormat, child) => Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              !exerciseSet.hasData
                  ? context.l10n.noDataYet
                  : dateFormat == 'timeago'
                  ? formatRelativeTime(context, exerciseSet.created)
                  : formatDisplayDate(context, exerciseSet.created, dateFormat),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ),
        trailing: exerciseSet.hasData
            ? Text(
                trailing,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              )
            : null,
        onTap: () async {
          if (selected.isNotEmpty) {
            onSelect(exerciseSet.selectionKey);
            return;
          }

          final data = await getInitialGraphData(exerciseSet);
          if (!context.mounted) return;
          Navigator.of(context).push(
            FlexPageRoute(
              builder: (context) => ExerciseGraphPage(
                initialName: exerciseSet.name,
                initialUnit: exerciseSet.unit,
                initialData: data,
                tabCtrl: tabCtrl,
                cardio: exerciseSet.cardio && !exerciseSet.bodyWeight,
                bodyWeight: exerciseSet.bodyWeight,
              ),
            ),
          );
        },
        onLongPress: desktop
            ? null
            : () {
                onSelect(exerciseSet.selectionKey);
              },
      ),
    );

    if (!desktop) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) async {
        final action = await showDesktopContextMenu<_GraphContextAction>(
          context,
          details.globalPosition,
          [
            if (onEdit != null)
              PopupMenuItem(
                value: _GraphContextAction.edit,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(context.l10n.actionEdit),
                ),
              ),
            if (onDelete != null)
              PopupMenuItem(
                value: _GraphContextAction.delete,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(context.l10n.actionDelete),
                ),
              ),
          ],
        );
        if (!context.mounted) return;
        switch (action) {
          case _GraphContextAction.edit:
            onEdit?.call();
            break;
          case _GraphContextAction.delete:
            await onDelete?.call();
            break;
          case null:
            break;
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: tile,
      ),
    );
  }
}
