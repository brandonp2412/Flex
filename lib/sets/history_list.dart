import 'package:flex/sets/history_list_state.dart';
import 'package:flex/exercise_avatar.dart';

import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/responsive.dart';
import 'package:flex/utils.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryList extends StatefulWidget {
  final List<ExerciseSetView> sets;
  final ScrollController scroll;
  final Function(int) onSelect;
  final Set<int> selected;
  final Function onNext;
  final bool bodyWeight;
  final Future<void> Function()? onChanged;
  final double topPadding;

  const HistoryList({
    super.key,
    required this.sets,
    required this.onSelect,
    required this.selected,
    required this.onNext,
    required this.scroll,
    this.bodyWeight = false,
    this.onChanged,
    this.topPadding = 0,
  });

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends HistoryListState<HistoryList> {
  @override
  ScrollController get scroll => widget.scroll;
  @override
  Function get onNext => widget.onNext;
  @override
  bool get bodyWeight => widget.bodyWeight;
  @override
  Future<void> Function()? get onChanged => widget.onChanged;
  List<ExerciseSetView> _current = [];

  @override
  void initState() {
    super.initState();
    _current = List.from(widget.sets);
  }

  @override
  void didUpdateWidget(HistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sets, widget.sets)) {
      setState(() {
        _current = List.from(widget.sets);
      });
    }
  }

  Widget _buildListItem(
    ExerciseSetView exerciseSet,
    int index,
    bool showImages, {
    bool showDayDivider = true,
    bool showTime = false,
  }) {
    final previous = index > 0 ? _current.elementAtOrNull(index - 1) : null;
    final bool showDivider =
        previous != null &&
        !DateUtils.isSameDay(exerciseSet.created, previous.created);

    final leading = showImages
        ? ExerciseAvatar(
            name: exerciseSet.name,
            image: exerciseSet.image,
            onTap: () => widget.onSelect(exerciseSet.id),
          )
        : null;

    final trailing = setSummary(context, exerciseSet);

    return Column(
      children: [
        if (showDivider && showDayDivider)
          Container(
            color:
                (widget.selected.contains(exerciseSet.id) &&
                    widget.selected.contains(previous.id))
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .18)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  const Icon(Icons.today),
                  const SizedBox(width: 4),
                  Selector<Setting, String>(
                    selector: (context, settings) => settings.shortDateFormat,
                    builder: (context, value, child) => Text(
                      formatDisplayDate(context, previous.created, value),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
          ),
        Builder(
          builder: (context) {
            final desktop = isDesktopLayout(context);
            final colors = Theme.of(context).colorScheme;
            final tile = Material(
              color: switch (desktop) {
                _ when widget.selected.contains(exerciseSet.id) =>
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
                      ? Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )
                      : null,
                ),
                subtitle: Selector<Setting, String>(
                  selector: (context, settings) => settings.longDateFormat,
                  builder: (context, dateFormat, child) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      switch (dateFormat) {
                        _ when showTime => TimeOfDay.fromDateTime(
                          exerciseSet.created,
                        ).format(context),
                        'timeago' => formatRelativeTime(
                          context,
                          exerciseSet.created,
                        ),
                        _ => formatDisplayDate(
                          context,
                          exerciseSet.created,
                          dateFormat,
                        ),
                      },
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                trailing: Text(
                  trailing,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                onLongPress: desktop
                    ? null
                    : () => widget.onSelect(exerciseSet.id),
                onTap: () {
                  if (widget.selected.isNotEmpty) {
                    widget.onSelect(exerciseSet.id);
                  } else {
                    editEntry(exerciseSet);
                  }
                },
              ),
            );
            if (!desktop) return tile;
            return ResponsiveContent(
              maxWidth: dataMaxWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapDown: (details) =>
                    showContextMenu(context, details, exerciseSet),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: tile,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showImages = context.select<Setting, bool>(
      (settings) => settings.showImages,
    );

    final wide =
        isDesktopLayout(context) && MediaQuery.sizeOf(context).width >= 1200;
    if (wide) {
      final rows = <(int, int?)>[];
      for (var index = 0; index < _current.length; index++) {
        if (index == 0 ||
            !DateUtils.isSameDay(
              _current[index].created,
              _current[index - 1].created,
            )) {
          rows.add((-1, index));
        }
        if (index + 1 < _current.length &&
            DateUtils.isSameDay(
              _current[index].created,
              _current[index + 1].created,
            )) {
          rows.add((index, ++index));
        } else {
          rows.add((index, null));
        }
      }
      return ListView.builder(
        padding: EdgeInsets.only(top: widget.topPadding, bottom: 32),
        controller: widget.scroll,
        itemCount: rows.length,
        itemBuilder: (context, rowIndex) {
          final row = rows[rowIndex];
          if (row.$1 == -1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 17),
                  const SizedBox(width: 10),
                  Selector<Setting, String>(
                    selector: (context, settings) => settings.shortDateFormat,
                    builder: (context, dateFormat, child) => Text(
                      formatDisplayDate(
                        context,
                        _current[row.$2!].created,
                        dateFormat,
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: Divider()),
                ],
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildListItem(
                  _current[row.$1],
                  row.$1,
                  showImages,
                  showDayDivider: false,
                  showTime: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: row.$2 == null
                    ? const SizedBox.shrink()
                    : _buildListItem(
                        _current[row.$2!],
                        row.$2!,
                        showImages,
                        showDayDivider: false,
                        showTime: true,
                      ),
              ),
            ],
          );
        },
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        top: widget.topPadding,
        bottom: isDesktopLayout(context) ? 32 : fabListPadding,
      ),
      controller: widget.scroll,
      itemCount: _current.length,
      itemBuilder: (context, index) {
        return _buildListItem(_current[index], index, showImages);
      },
    );
  }
}
