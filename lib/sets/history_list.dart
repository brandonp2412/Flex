import 'package:flex/sets/history_list_state.dart';

import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/responsive.dart';
import 'package:flex/utils.dart';
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
  Set<int> get selected => widget.selected;
  @override
  void select(int id) => widget.onSelect(id);
  @override
  bool get bodyWeight => widget.bodyWeight;
  @override
  Future<void> Function()? get onChanged => widget.onChanged;
  List<ExerciseSetView> get _current => widget.sets;

  Widget _buildListItem(
    ExerciseSetView exerciseSet,
    int index, {
    bool showDayDivider = true,
    bool showTime = false,
  }) {
    final previous = index > 0 ? _current.elementAtOrNull(index - 1) : null;
    final bool showDivider =
        previous != null &&
        !DateUtils.isSameDay(exerciseSet.created, previous.created);

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
            final tile = entryTile(context, exerciseSet, showTime: showTime);
            return isDesktopLayout(context)
                ? ResponsiveContent(maxWidth: dataMaxWidth, child: tile)
                : tile;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
        return _buildListItem(_current[index], index);
      },
    );
  }
}
