import 'dart:collection';

import 'package:flex/search_list_scaffold.dart';
import 'package:flex/app_search.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/error_state.dart';
import 'package:flex/filters.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/sets/edit_sets_page.dart';
import 'package:flex/sets/group_history.dart';
import 'package:flex/sets/history_grouping_cache.dart';
import 'package:flex/sets/history_filters.dart';
import 'package:flex/sets/history_list.dart';
import 'package:flex/sets/history_page.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class HistoryPageWidget extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const HistoryPageWidget({super.key, required this.navigatorKey});

  @override
  createState() => _HistoryPageWidgetState();
}

class _HistoryPageWidgetState extends State<HistoryPageWidget> {
  late Stream<List<ExerciseSetView>> stream;

  final _filters = HistoryFilters();
  final scroll = ScrollController();
  final _selection = <int>{};
  final _historyGroups = HistoryGroupingCache();

  final _searchController = TextEditingController();
  String get search => _searchController.text;
  int limit = 100;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        final rows = snapshot.data;
        final groupHistory = context.select<Setting, bool>(
          (settings) => settings.groupHistory,
        );
        void select(int id) => setState(() {
          if (!_selection.remove(id)) _selection.add(id);
        });
        void next() {
          limit += 100;
          setStream();
        }

        return SearchListScaffold(
          title: context.l10n.navHistory,
          addLabel: context.l10n.addSet,
          onAdd: onAdd,
          showAdd: search.trim().isEmpty || rows == null || rows.isNotEmpty,
          scroll: scroll,
          body: ResponsiveContent(
            maxWidth: dataMaxWidth,
            desktopPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: searchListBody(
              list: snapshot.hasError
                  ? const AppErrorState()
                  : rows == null
                  ? const SizedBox.shrink()
                  : rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: appSearchHeight),
                      child: AppEmptyState(
                        icon: Icons.history_rounded,
                        title: context.l10n.noEntriesYet,
                        message: context.l10n.historyEmptyMessage,
                        actionLabel: context.l10n.addSet,
                        actionIcon: Icons.add_rounded,
                        onAction: search.trim().isEmpty ? null : onAdd,
                      ),
                    )
                  : groupHistory
                  ? GroupHistory(
                      scroll: scroll,
                      days: _historyGroups.get(rows),
                      onSelect: select,
                      selected: _selection,
                      onNext: next,
                    )
                  : HistoryList(
                      scroll: scroll,
                      topPadding: appSearchHeight + 8,
                      sets: rows,
                      onSelect: select,
                      selected: _selection,
                      onNext: next,
                    ),
              search: AppSearch(
                hintText: context.l10n.searchHistory,
                controller: _selection,
                filter: Filters(
                  filters: _filters,
                  onChanged: () {
                    limit = 100;
                    setStream();
                  },
                ),
                onShare: () async {
                  final exerciseSets = snapshot.data!
                      .where(
                        (exerciseSet) => _selection.contains(exerciseSet.id),
                      )
                      .toList();
                  final summaries = exerciseSets
                      .map(
                        (exerciseSet) =>
                            "${formatDisplayNumber(context, exerciseSet.reps)}×${formatDisplayNumber(context, exerciseSet.weight)}${displayMeasurementUnit(context.l10n, exerciseSet.unit)} ${exerciseSet.name}",
                      )
                      .join(', ');
                  await SharePlus.instance.share(
                    ShareParams(text: context.l10n.shareWorkout(summaries)),
                  );
                  if (!mounted) return;
                  setState(() {
                    _selection.clear();
                  });
                },
                textController: _searchController,
                onChange: (_) {
                  limit = 100;
                  setStream();
                },
                onClearSelection: () => setState(() {}),
                onDelete: () async {
                  await deleteExerciseSets(db, _selection);
                  setState(() {
                    _selection.clear();
                  });
                },
                onSelectAll: selectAllFiltered,
                onEdit: () => Navigator.of(context).push(
                  FlexPageRoute(
                    builder: (context) =>
                        EditSetsPage(ids: _selection.toList()),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void onAdd() async {
    final settings = context.read<Setting>();
    final setsFuture = stream.first;
    final weightFuture = settings.showBodyWeight
        ? getLatestBodyWeight(db)
        : Future<BodyWeight?>.value();
    final exerciseSets = await setsFuture;
    final lastWeight = await weightFuture;

    ExerciseSetView exerciseSet =
        exerciseSets.firstOrNull ??
        ExerciseSetView(
          id: 0,
          bodyWeight: 0,
          restMs: const Duration(minutes: 3, seconds: 30).inMilliseconds,
          name: '',
          reps: 0,
          created: DateTime.now().toLocal(),
          unit: 'kg',
          weight: 0,
          cardio: false,
          duration: 0,
          distance: 0,
        );
    exerciseSet = exerciseSet.copyWith(
      id: 0,
      bodyWeight: 0,
      created: DateTime.now().toLocal(),
    );

    if (settings.strengthUnit != 'last-entry' && !exerciseSet.cardio) {
      exerciseSet = exerciseSet.copyWith(unit: settings.strengthUnit);
    } else if (settings.cardioUnit != 'last-entry' && exerciseSet.cardio) {
      exerciseSet = exerciseSet.copyWith(unit: settings.cardioUnit);
    }

    if (lastWeight != null) {
      exerciseSet = exerciseSet.copyWith(
        bodyWeight: displayLoad(exerciseSet.unit, lastWeight.weightKg),
      );
    }

    if (!mounted) return;
    Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => EditSetPage(exerciseSet: exerciseSet),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filters.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setStream();
  }

  ExerciseSetQuery _filteredQuery({int? rowLimit}) =>
      _filters.query(db, context, search: search, limit: rowLimit);

  Future<void> selectAllFiltered() async {
    final ids = await _filteredQuery().getIds();
    if (!mounted) return;
    setState(() {
      _selection.addAll(ids);
    });
  }

  void setStream() {
    setState(() {
      stream = _filteredQuery(rowLimit: limit).watch();
    });
  }
}
