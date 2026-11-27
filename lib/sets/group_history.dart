import 'package:flex/sets/history_list_state.dart';
import 'package:flex/exercise_summary_tile.dart';

import 'package:flex/app_search.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/responsive.dart';
import 'package:flex/sets/history_page.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GroupHistory extends StatefulWidget {
  final List<HistoryDayGroup> days;
  final ScrollController scroll;
  final Function(int) onSelect;
  final Set<int> selected;
  final Function onNext;
  const GroupHistory({
    super.key,
    required this.days,
    required this.onSelect,
    required this.selected,
    required this.onNext,
    required this.scroll,
  });

  @override
  State<GroupHistory> createState() => _GroupHistoryState();
}

class _GroupHistoryState extends HistoryListState<GroupHistory> {
  @override
  ScrollController get scroll => widget.scroll;
  @override
  Function get onNext => widget.onNext;

  @override
  Widget build(BuildContext context) {
    final shortDateFormat = context.select<Setting, String>(
      (settings) => settings.shortDateFormat,
    );
    final desktop = isDesktopLayout(context);

    return ListView.builder(
      itemCount: widget.days.length,
      padding: EdgeInsets.only(
        bottom: desktop ? 32 : fabListPadding,
        top: appSearchHeight + 8,
      ),
      controller: widget.scroll,
      itemBuilder: (context, index) =>
          _dayCard(context, widget.days[index], shortDateFormat, desktop),
    );
  }

  Widget _dayCard(
    BuildContext context,
    HistoryDayGroup group,
    String shortDateFormat,
    bool desktop,
  ) {
    return Card(
      margin: desktop
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dayHeader(context, group, shortDateFormat),
          for (final exercise in group.exercises)
            _exerciseTile(context, group, exercise),
        ],
      ),
    );
  }

  Widget _dayHeader(
    BuildContext context,
    HistoryDayGroup group,
    String shortDateFormat,
  ) {
    final colors = Theme.of(context).colorScheme;
    final weekday = formatDisplayDate(context, group.day, 'EEE');
    final date = formatDisplayDate(context, group.day, shortDateFormat);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .35),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$weekday, $date',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseTile(
    BuildContext context,
    HistoryDayGroup group,
    HistoryDay exercise,
  ) {
    final count = formatDisplayNumber(
      context,
      exercise.exerciseSets.length,
      maxDigits: 0,
    );

    return ExpansionTile(
      key: ValueKey('${group.day.millisecondsSinceEpoch}|${exercise.name}'),
      title: Text('${exercise.name} ($count)'),
      shape: const Border.symmetric(),
      children: [
        for (final exerciseSet in exercise.exerciseSets)
          Builder(builder: (context) => _setRow(context, exerciseSet)),
      ],
    );
  }

  Widget _setRow(BuildContext context, ExerciseSetView exerciseSet) {
    return ExerciseSummaryTile(
      name: exerciseSet.name,
      summary: setSummary(context, exerciseSet),
      created: exerciseSet.created,
      image: exerciseSet.image,
      selected: widget.selected.contains(exerciseSet.id),
      selectionActive: widget.selected.isNotEmpty,
      onSelect: () => widget.onSelect(exerciseSet.id),
      onOpen: () => editEntry(exerciseSet),
      onSecondaryTapDown: (details) =>
          showContextMenu(context, details, exerciseSet),
      grouped: true,
    );
  }
}
