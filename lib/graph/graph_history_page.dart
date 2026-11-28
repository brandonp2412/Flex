import 'package:flex/error_state.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flex/app_confirmation.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/empty_state.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/sets/edit_sets_page.dart';
import 'package:flex/sets/history_list.dart';
import 'package:flutter/material.dart';

class GraphHistoryPage extends StatefulWidget {
  final String name;
  final bool bodyWeight;

  const GraphHistoryPage({
    super.key,
    required this.name,
    this.bodyWeight = false,
  });

  @override
  createState() => _GraphHistoryPageState();
}

class _GraphHistoryPageState extends State<GraphHistoryPage> {
  final _selection = <int>{};
  int limit = 20;
  late Stream<List<ExerciseSetView>> _sets = _watchSets();

  Stream<List<ExerciseSetView>> _watchSets() => watchGraphHistory(
    widget.name,
    bodyWeight: widget.bodyWeight,
    limit: limit,
  );

  final scroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExerciseSetView>>(
      stream: _sets,
      builder: (context, snapshot) {
        final sets = snapshot.data;
        return PopScope(
          canPop: _selection.isEmpty,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || _selection.isEmpty) return;
            setState(_selection.clear);
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: _buildAppBar(sets ?? const []),
            body: Builder(
              builder: (context) {
                if (snapshot.hasError) return const AppErrorState();
                if (sets == null) return const SizedBox.shrink();
                if (sets.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.history_rounded,
                    title: context.l10n.noHistoryFor(widget.name),
                    message: context.l10n.completeSetsForHistory,
                  );
                }

                return HistoryList(
                  scroll: scroll,
                  sets: sets,
                  onSelect: (id) => setState(() {
                    if (!_selection.remove(id)) _selection.add(id);
                  }),
                  selected: _selection,
                  bodyWeight: widget.bodyWeight,
                  onNext: () {
                    setState(() {
                      limit += 10;
                      _sets = _watchSets();
                    });
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(List<ExerciseSetView> sets) {
    if (_selection.isEmpty) return AppBar(title: Text(widget.name));

    return AppBar(
      leading: IconButton(
        key: const ValueKey('clearGraphHistorySelection'),
        tooltip: context.l10n.cancelSelection,
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selection.clear),
      ),
      title: Text(context.l10n.selectedCount(_selection.length)),
      actions: [
        IconButton(
          key: const ValueKey('selectAllGraphHistory'),
          tooltip: context.l10n.selectAll,
          icon: const Icon(Icons.done_all),
          onPressed: () => setState(
            () => _selection.addAll(sets.map((exerciseSet) => exerciseSet.id)),
          ),
        ),
        if (!widget.bodyWeight)
          IconButton(
            key: const ValueKey('editGraphHistorySelection'),
            tooltip: context.l10n.editSelected,
            icon: const Icon(Icons.edit),
            onPressed: _editSelected,
          ),
        IconButton(
          key: const ValueKey('deleteGraphHistorySelection'),
          tooltip: context.l10n.deleteSelected,
          icon: const Icon(Icons.delete),
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  Future<void> _editSelected() async {
    if (widget.bodyWeight) return;
    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => EditSetsPage(ids: _selection.toList()),
      ),
    );
    if (!mounted) return;
    setState(_selection.clear);
  }

  Future<void> _deleteSelected() async {
    final count = _selection.length;
    final confirmed = await showAppConfirmation(
      context,
      title: context.l10n.confirmDelete,
      message: context.l10n.deleteRecordsConfirmation(count),
      actionLabel: context.l10n.actionDelete,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    final ids = _selection.toList();
    if (widget.bodyWeight) {
      await (db.bodyWeights.delete()..where((row) => row.id.isIn(ids))).go();
    } else {
      await deleteExerciseSets(db, ids);
    }
    if (!mounted) return;
    setState(_selection.clear);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }
}
