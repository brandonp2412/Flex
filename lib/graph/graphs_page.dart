import 'graph_tile.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/app_confirmation.dart';
import 'package:flex/app_fab.dart';
import 'package:flex/app_search.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/error_state.dart';

import 'package:flex/graph/cardio_data.dart';
import 'package:flex/graph/graph_data.dart';
import 'package:flex/graph/strength_data.dart';
import 'package:flex/graph/exercise_editor_page.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/global_progress_page.dart';
import 'package:flex/graph/merge_graphs_page.dart';
import 'package:flex/graphs_filters.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

void applyGraphSortToNewestFirstSummaries(
  List<GraphExerciseSummary> summaries,
  GraphSort sort,
) {
  switch (sort) {
    case GraphSort.dateDesc:
      break;
    case GraphSort.dateAsc:
      for (var i = 0, j = summaries.length - 1; i < j; i++, j--) {
        final item = summaries[i];
        summaries[i] = summaries[j];
        summaries[j] = item;
      }
      break;
    case GraphSort.name:
      summaries.sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
      break;
  }
}

List<GraphExerciseSummary> filterGraphSummaries(
  List<GraphExerciseSummary> summaries,
  String search,
  String? category,
) {
  final terms = search
      .toLowerCase()
      .split(' ')
      .where((term) => term.isNotEmpty)
      .toList();
  return [
    for (final summary in summaries)
      if ((category == null || summary.category == category) &&
          terms.every(summary.normalizedName.contains))
        summary,
  ];
}

class GraphsPage extends StatefulWidget {
  final TabController tabController;

  const GraphsPage({super.key, required this.tabController});

  @override
  createState() => GraphsPageState();
}

class GraphsPageState extends State<GraphsPage>
    with AutomaticKeepAliveClientMixin {
  late final Stream<List<GraphExerciseSummary>> _stream = watchGraphs();

  GraphExerciseSummary? _peekSummary;
  Future<List<GraphData>>? _peekFuture;

  Future<List<GraphData>> _peekData(GraphExerciseSummary summary) {
    if (!identical(_peekSummary, summary)) {
      _peekSummary = summary;
      _peekFuture = getInitialGraphData(summary);
    }
    return _peekFuture!;
  }

  final _selection = <String>{};
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  String _search = '';
  String? _category;
  final _scroll = ScrollController();
  int _total = 0;
  GraphSort _sort = GraphSort.dateDesc;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NavigatorPopHandler(
      onPopWithResult: (result) {
        if (navKey.currentState!.canPop() == false) return;
        final settings = context.read<Setting>();
        final graphsIndex = settings.tabs.split(',').indexOf('GraphsPage');
        if (widget.tabController.index == graphsIndex)
          Navigator.of(navKey.currentContext!).pop();
      },
      child: Navigator(
        key: navKey,
        onGenerateRoute: (settings) => FlexPageRoute(
          builder: (context) => graphsPage(),
          settings: settings,
        ),
      ),
    );
  }

  Future<void> onDelete() async {
    final keys = Set<String>.of(_selection);
    final summaries = filterGraphSummariesBySelection(
      await _stream.first,
      keys,
    );
    final exerciseIds = summaries
        .where((summary) => !summary.bodyWeight)
        .map((summary) => summary.exerciseId!)
        .toList();
    final deleteWeight = summaries.any((summary) => summary.bodyWeight);

    setState(_selection.clear);

    await db.transaction(() async {
      if (deleteWeight) {
        await db.bodyWeights.deleteAll();
      }
      if (exerciseIds.isNotEmpty) {
        await (db.exerciseSets.delete()
              ..where((set) => set.exerciseId.isIn(exerciseIds)))
            .go();
        await (db.planExercises.delete()
              ..where((row) => row.exerciseId.isIn(exerciseIds)))
            .go();
        await (db.exercises.delete()
              ..where((exercise) => exercise.id.isIn(exerciseIds)))
            .go();
      }
    });
  }

  Future<int> _countSelectedGraphRecords() async {
    final keys = Set<String>.of(_selection);
    final summaries = filterGraphSummariesBySelection(
      await _stream.first,
      keys,
    );
    var count = await countGraphSets(
      summaries
          .where((summary) => !summary.bodyWeight)
          .map((summary) => summary.name),
    );
    if (summaries.any((summary) => summary.bodyWeight)) {
      count += await db.bodyWeights.count().getSingle();
    }
    return count;
  }

  Future<void> _editGraphSummary(GraphExerciseSummary summary) async {
    if (summary.bodyWeight) return;
    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => ExerciseEditorPage.edit(name: summary.name),
      ),
    );
  }

  Future<void> _deleteGraphSummary(GraphExerciseSummary summary) async {
    final count = summary.bodyWeight
        ? await db.bodyWeights.count().getSingle()
        : await countGraphSets([summary.name]);
    if (!mounted) return;
    final confirmed = await showAppConfirmation(
      context,
      title: context.l10n.confirmDelete,
      message: context.l10n.deleteGraphRecordsConfirmation(count),
      actionLabel: context.l10n.actionDelete,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _selection.addAll([summary.selectionKey]);
    });
    await onDelete();
  }

  Future<void> _hideGlobalProgressAt(Offset position) async {
    final hide = await showDesktopContextMenu<bool>(context, position, [
      PopupMenuItem(
        value: true,
        child: ListTile(
          leading: const Icon(Icons.visibility_off_outlined),
          title: Text(context.l10n.hideGlobalProgress),
        ),
      ),
    ]);
    if (hide == true) {
      await db.settings.update().write(
        const SettingsCompanion(showGlobalProgress: Value(false)),
      );
    }
  }

  String tooltipText(
    List<GraphData> data,
    String unit,
    String format,
    int index,
  ) {
    final row = data.elementAt(index);
    final created = formatDisplayDate(context, row.created, format);

    if (row is CardioData) {
      return "${formatDisplayNumber(context, row.value)} ${displayMeasurementUnit(context.l10n, row.unit)} / ${context.l10n.minutesShort}";
    }

    return "${formatDisplayNumber(context, (row as StrengthData).reps, maxDigits: 0)} × ${formatDisplayNumber(context, row.value, minDigits: 2)}${displayMeasurementUnit(context.l10n, unit)} $created";
  }

  Widget getPeek(
    GraphExerciseSummary exerciseSet,
    List<GraphData> data,
    String format,
  ) {
    final points = [
      for (var index = 0; index < data.length; index++)
        FlexLineChartPoint(index.toDouble(), data[index].value),
    ];

    return Padding(
      padding: const EdgeInsets.only(
        right: 48.0,
        top: 16.0,
        left: 48.0,
        bottom: 16.0,
      ),
      child: FlexLineChart(
        points: points,
        tooltipText: (index) =>
            tooltipText(data, exerciseSet.unit, format, index),
        hideBottom: true,
        hideLeft: true,
        showTrendLine: false,
      ),
    );
  }

  Widget _peekPreview(GraphExerciseSummary summary, String dateFormat) {
    return FutureBuilder<List<GraphData>>(
      future: _peekData(summary),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            data == null ||
            data.length < 2) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          key: const Key('graphs-peek-preview'),
          height: MediaQuery.sizeOf(context).height * 0.15,
          child: getPeek(summary, data, dateFormat),
        );
      },
    );
  }

  Scaffold graphsPage() {
    final desktop = isDesktopLayout(context);
    return Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      resizeToAvoidBottomInset: false,
      appBar: desktop
          ? AppBar(
              title: Text(context.l10n.navGraphs),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: FilledButton.icon(
                    onPressed: () => navKey.currentState!.push(
                      FlexPageRoute(
                        builder: (context) => const ExerciseEditorPage.add(),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.addExercise),
                  ),
                ),
              ],
            )
          : null,
      body: ResponsiveContent(
        maxWidth: dataMaxWidth,
        desktopPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: StreamBuilder(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AppErrorState();
            }
            if (!snapshot.hasData) return const SizedBox();

            final exerciseSets = filterGraphSummaries(
              snapshot.data!,
              _search,
              _category,
            );
            applyGraphSortToNewestFirstSummaries(exerciseSets, _sort);
            return Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Selector<Setting, bool>(
                        selector: (context, settings) =>
                            settings.showGlobalProgress,
                        builder: (context, showGlobal, child) {
                          final progressTerms =
                              '${context.l10n.globalProgress} ${context.l10n.navGraphs}'
                                  .toLowerCase();
                          final showProgress =
                              showGlobal &&
                              _category == null &&
                              progressTerms.contains(_search.toLowerCase());
                          final showEmpty =
                              exerciseSets.isEmpty && !showProgress;
                          return Expanded(
                            child: showEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      top: appSearchHeight,
                                    ),
                                    child: AppEmptyState(
                                      icon: Icons.search_off_rounded,
                                      title: context.l10n.noGraphsFound,
                                      message: _search.trim().isEmpty
                                          ? context
                                                .l10n
                                                .completeSetForFirstGraph
                                          : context.l10n
                                                .nothingMatchesGraphSearch(
                                                  _search.trim(),
                                                ),
                                      actionLabel: _search.trim().isEmpty
                                          ? context.l10n.addExercise
                                          : context.l10n.addNamed(
                                              _search.trim(),
                                            ),
                                      actionIcon: Icons.add_rounded,
                                      onAction: () =>
                                          Navigator.of(context).push(
                                            FlexPageRoute(
                                              builder: (context) =>
                                                  ExerciseEditorPage.add(
                                                    name: _search,
                                                  ),
                                            ),
                                          ),
                                    ),
                                  )
                                : graphList(exerciseSets, showGlobal),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppSearch(
                    hintText: context.l10n.searchGraphs,
                    controller: _selection,
                    filter: GraphsFilters(
                      category: _category,
                      setCategory: (value) {
                        setState(() {
                          _category = value;
                        });
                      },
                      sort: _sort,
                      setSort: (value) {
                        setState(() {
                          _sort = value;
                        });
                      },
                    ),
                    onShare: onShare,
                    onMerge: _openMergeGraphs,
                    onChange: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                    onDelete: () async => onDelete(),
                    onSelectAll: () async {
                      setState(() {
                        _selection.addAll(
                          exerciseSets.map(
                            (exerciseSet) => exerciseSet.selectionKey,
                          ),
                        );
                      });
                      final total = await _countSelectedGraphRecords();
                      if (!mounted) return;
                      setState(() => _total = total);
                    },
                    onEdit: () async {
                      final key = _selection.first;
                      final summary = (await _stream.first).firstWhere(
                        (entry) => entry.selectionKey == key,
                      );
                      if (summary.bodyWeight || !context.mounted) return;
                      await Navigator.of(context).push(
                        FlexPageRoute(
                          builder: (context) =>
                              ExerciseEditorPage.edit(name: summary.name),
                        ),
                      );
                    },
                    confirmText: context.l10n.deleteGraphRecordsConfirmation(
                      _total,
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
              onPressed: () => navKey.currentState!.push(
                FlexPageRoute(
                  builder: (context) => const ExerciseEditorPage.add(),
                ),
              ),
              label: Text(context.l10n.actionAdd),
              scroll: _scroll,
              icon: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _openMergeGraphs() async {
    final summaries = filterGraphSummariesBySelection(
      await _stream.first,
      Set<String>.of(_selection),
    );
    if (summaries.length < 2 || !mounted) return;
    final merged = await navKey.currentState!.push<bool>(
      FlexPageRoute(
        builder: (context) => MergeGraphsPage(summaries: summaries),
      ),
    );
    if (merged == true && mounted) setState(_selection.clear);
  }

  Future<void> onShare() async {
    final l10n = context.l10n;
    final copy = Set<String>.of(_selection);
    setState(() {
      _selection.clear();
    });
    final sets = filterGraphSummariesBySelection(await _stream.first, copy);
    final text = sets
        .map(
          (exerciseSet) =>
              "${formatDisplayNumber(context, exerciseSet.reps)}×${formatDisplayNumber(context, exerciseSet.weight)}${displayMeasurementUnit(l10n, exerciseSet.unit)} ${exerciseSet.name}",
        )
        .join(', ');
    await SharePlus.instance.share(ShareParams(text: l10n.shareWorkout(text)));
  }

  void longPressGlobal() {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.visibility_off),
                title: Text(context.l10n.hideGlobalProgress),
                onTap: () {
                  db.settings.update().write(
                    const SettingsCompanion(showGlobalProgress: Value(false)),
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear),
                title: Text(context.l10n.actionCancel),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget graphList(List<GraphExerciseSummary> exerciseSets, bool showProgress) {
    final desktop = isDesktopLayout(context);
    final progressTerms =
        '${context.l10n.globalProgress} ${context.l10n.navGraphs}'
            .toLowerCase();
    final showGlobal =
        showProgress &&
        _category == null &&
        progressTerms.contains(_search.toLowerCase());
    final preview = exerciseSets
        .where((summary) => summary.hasData)
        .firstOrNull;
    final showPeek = context.read<Setting>().peekGraph && preview != null;

    Widget tile(BuildContext context, int index) {
      final summary = exerciseSets[index];
      final tile = GraphTile(
        selected: _selection,
        exerciseSet: summary,
        onSelect: (key) async {
          setState(() {
            if (!_selection.remove(key)) _selection.add(key);
          });
          final total = await _countSelectedGraphRecords();
          if (mounted) setState(() => _total = total);
        },
        tabCtrl: widget.tabController,
        onEdit: summary.bodyWeight ? null : () => _editGraphSummary(summary),
        onDelete: () => _deleteGraphSummary(summary),
      );
      return desktop ? tile : ResponsiveContent(child: tile);
    }

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: appSearchHeight + 8)),
        if (showGlobal) SliverToBoxAdapter(child: _globalProgressTile(desktop)),
        if (showPeek)
          SliverToBoxAdapter(
            child: Consumer<Setting>(
              builder: (context, settings, _) => settings.peekGraph
                  ? _peekPreview(preview, settings.shortDateFormat)
                  : const SizedBox(),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(
            top: desktop ? 4 : 0,
            bottom: desktop ? 32 : fabListPadding,
          ),
          sliver: desktop
              ? SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 620,
                    mainAxisExtent: 94,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: exerciseSets.length,
                  itemBuilder: tile,
                )
              : SliverList.builder(
                  itemCount: exerciseSets.length,
                  itemBuilder: tile,
                ),
        ),
      ],
    );
  }

  Widget _globalProgressTile(bool desktop) {
    final tile = Material(
      color: desktop
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Colors.transparent,
      borderRadius: desktop ? BorderRadius.circular(16) : null,
      clipBehavior: desktop ? Clip.antiAlias : Clip.none,
      child: ListTile(
        contentPadding: desktop
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 9)
            : null,
        leading: const Icon(Icons.language),
        title: Text(
          context.l10n.globalProgress,
          style: desktop
              ? Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
              : null,
        ),
        subtitle: Text(context.l10n.chartGroupedByCategory),
        trailing: desktop ? const Icon(Icons.chevron_right_rounded) : null,
        onTap: () => Navigator.of(context).push(
          FlexPageRoute(
            builder: (context) =>
                GlobalProgressPage(tabController: widget.tabController),
          ),
        ),
        onLongPress: desktop ? null : longPressGlobal,
      ),
    );
    return desktop
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapDown: (details) =>
                  _hideGlobalProgressAt(details.globalPosition),
              child: tile,
            ),
          )
        : ResponsiveContent(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: tile,
            ),
          );
  }
}
