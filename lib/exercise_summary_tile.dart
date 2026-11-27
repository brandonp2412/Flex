import 'package:flex/database/database.dart';
import 'package:flex/exercise_avatar.dart';
import 'package:flex/responsive.dart';
import 'package:flex/selection_tile.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExerciseSummaryTile extends StatelessWidget {
  const ExerciseSummaryTile({
    super.key,
    required this.name,
    required this.summary,
    required this.created,
    required this.selected,
    required this.selectionActive,
    required this.onSelect,
    required this.onOpen,
    this.image,
    this.showTime = false,
    this.grouped = false,
    this.emptyLabel,
    this.desktopPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 5,
    ),
    this.onSecondaryTapDown,
    this.graph = false,
  });

  final String name, summary;
  final String? image, emptyLabel;
  final DateTime created;
  final bool selected, selectionActive, showTime, grouped, graph;
  final VoidCallback onSelect, onOpen;
  final GestureTapDownCallback? onSecondaryTapDown;
  final EdgeInsets desktopPadding;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    final theme = Theme.of(context);
    final showImages = context.select<Setting, bool>(
      (settings) => settings.showImages,
    );
    return SelectionTile(
      selected: selected,
      selectionActive: selectionActive,
      onSelect: onSelect,
      onOpen: onOpen,
      onSecondaryTapDown: onSecondaryTapDown,
      grouped: grouped,
      desktopPadding: desktopPadding,
      leading: showImages
          ? ExerciseAvatar(name: name, image: image, onTap: onSelect)
          : null,
      title: Text(
        grouped ? summary : name,
        style: desktop && !grouped
            ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
            : null,
      ),
      subtitle: Selector<Setting, String>(
        selector: (context, settings) => settings.longDateFormat,
        builder: (context, dateFormat, child) {
          final text = Text(
            emptyLabel ??
                (showTime
                    ? TimeOfDay.fromDateTime(created).format(context)
                    : dateFormat == 'timeago'
                    ? formatRelativeTime(context, created)
                    : formatDisplayDate(context, created, dateFormat)),
            style: grouped
                ? null
                : theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          );
          return grouped
              ? text
              : Padding(padding: const EdgeInsets.only(top: 3), child: text);
        },
      ),
      trailing: grouped || emptyLabel != null
          ? null
          : Text(
              summary,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: graph ? theme.colorScheme.onSurface : null,
              ),
            ),
    );
  }
}
