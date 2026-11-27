import 'dart:collection';

import 'package:flex/app_fab.dart';
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

  final repsGt = TextEditingController();
  final repsLt = TextEditingController();
  final weightGt = TextEditingController();
  final weightLt = TextEditingController();
  final scroll = ScrollController();
  final _selection = <int>{};
  final _historyGroups = HistoryGroupingCache();

  String search = '';
  int limit = 100;
  DateTime? startDate;
  DateTime? endDate;
  String? category;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      resizeToAvoidBottomInset: false,
      appBar: desktop
          ? AppBar(
              title: Text(context.l10n.navHistory),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.addSet),
                  ),
                ),
              ],
            )
          : null,
      body: ResponsiveContent(
        maxWidth: dataMaxWidth,
        desktopPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: StreamBuilder(
          stream: stream,
          builder: (context, snapshot) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      if (!snapshot.hasError && snapshot.data?.isEmpty == true)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: appSearchHeight,
                            ),
                            child: AppEmptyState(
                              icon: Icons.history_rounded,
                              title: context.l10n.noEntriesYet,
                              message: context.l10n.historyEmptyMessage,
                              actionLabel: context.l10n.addSet,
                              actionIcon: Icons.add_rounded,
                              onAction: onAdd,
                            ),
                          ),
                        ),
                      if (snapshot.hasError)
                        Expanded(child: const AppErrorState()),
                      if (!snapshot.hasError &&
                          snapshot.hasData &&
                          snapshot.data!.isNotEmpty)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final groupHistory = context
                                  .select<Setting, bool>(
                                    (settings) => settings.groupHistory,
                                  );

                              if (groupHistory) {
                                final dayGroups = _historyGroups.get(
                                  snapshot.data!,
                                );
                                return GroupHistory(
                                  scroll: scroll,
                                  days: dayGroups,
                                  onSelect: (id) {
                                    setState(() {
                                      if (!_selection.remove(id))
                                        _selection.add(id);
                                    });
                                  },
                                  selected: _selection,
                                  onNext: () {
                                    setState(() {
                                      limit += 100;
                                    });
                                    setStream();
                                  },
                                );
                              } else
                                return HistoryList(
                                  scroll: scroll,
                                  topPadding: appSearchHeight + 8,
                                  sets: snapshot.data!,
                                  onSelect: (id) {
                                    setState(() {
                                      if (!_selection.remove(id))
                                        _selection.add(id);
                                    });
                                  },
                                  selected: _selection,
                                  onNext: () {
                                    setState(() {
                                      limit += 100;
                                    });
                                    setStream();
                                  },
                                );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppSearch(
                    hintText: context.l10n.searchHistory,
                    controller: _selection,
                    filter: Filters(
                      repsGtCtrl: repsGt,
                      repsLtCtrl: repsLt,
                      weightGtCtrl: weightGt,
                      weightLtCtrl: weightLt,
                      setStream: () {
                        setState(() {
                          limit = 100;
                        });
                        setStream();
                      },
                      endDate: endDate,
                      startDate: startDate,
                      setEnd: (value) {
                        setState(() {
                          endDate = value;
                          limit = 100;
                        });
                        setStream();
                      },
                      setStart: (value) {
                        setState(() {
                          startDate = value;
                          limit = 100;
                        });
                        setStream();
                      },
                      category: category,
                      setCategory: (value) {
                        setState(() {
                          category = value;
                          limit = 100;
                        });
                        setStream();
                      },
                    ),
                    onShare: () async {
                      final exerciseSets = snapshot.data!
                          .where(
                            (exerciseSet) =>
                                _selection.contains(exerciseSet.id),
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
                    onChange: (value) {
                      setState(() {
                        search = value;
                        limit = 100;
                      });
                      setStream();
                    },
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
              ],
            );
          },
        ),
      ),
      floatingActionButton: desktop
          ? null
          : AppFab(
              onPressed: onAdd,
              label: Text(context.l10n.actionAdd),
              icon: const Icon(Icons.add),
              scroll: scroll,
            ),
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
        bodyWeight: displayBodyWeight(exerciseSet.unit, lastWeight.weightKg),
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
    repsGt.dispose();
    repsLt.dispose();
    weightGt.dispose();
    weightLt.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setStream();
  }

  ExerciseSetQuery _filteredQuery({int? rowLimit}) => ExerciseSetQuery(
    db,
    search: search,
    category: category,
    startDate: startDate,
    endDate: endDate,
    repsGt: parseDisplayNumber(context, repsGt.text),
    repsLt: parseDisplayNumber(context, repsLt.text),
    weightGt: parseDisplayNumber(context, weightGt.text),
    weightLt: parseDisplayNumber(context, weightLt.text),
    limit: rowLimit,
  );

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
