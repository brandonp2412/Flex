import 'dart:async';

import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/graph/graph_history_page.dart';
import 'package:flex/graph/graph_notes_page.dart';
import 'package:flex/graph/graph_options_controls.dart';
import 'package:flex/main.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/responsive.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class ExerciseGraphState<T extends StatefulWidget, M extends Enum>
    extends State<T> {
  late String targetUnit;
  late String exerciseName;
  late bool timeAxis;
  late int limit;
  late M metric;
  int dataRequest = 0;
  late Period period;
  DateTime? start;
  DateTime? end;
  DateTime lastTap = DateTime(0);
  Timer? _refreshTimer;
  Timer? _notesDebounce;
  final notesCtrl = TextEditingController();

  TabController get tabController;
  bool get bodyWeight => false;
  List<DropdownMenuItem<String>> get optionsUnits;
  DateTime? pointDate(int index);
  Future<void> setData();

  Future<void> savePreferences() async {
    if (bodyWeight) return;
    final exercise = await getExerciseByName(db, exerciseName);
    if (exercise == null) return;
    await updateExerciseGraphPreferences(
      db,
      exerciseId: exercise.id,
      metric: metric.name,
      period: period.name,
      limit: limit,
      timeBasedXAxis: timeAxis,
      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
    );
  }

  void _onNotesChanged() {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 600), savePreferences);
  }

  Future<void> editNotes() async {
    await Navigator.of(context, rootNavigator: true).push(
      FlexPageRoute(
        builder: (context) =>
            GraphNotesPage(controller: notesCtrl, onChanged: _onNotesChanged),
      ),
    );
    _notesDebounce?.cancel();
    await savePreferences();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notesDebounce?.cancel();
    notesCtrl.dispose();
    tabController.removeListener(onTabChanged);
    super.dispose();
  }

  void onTabChanged() {
    final settings = context.read<Setting>();
    if (tabController.index == settings.tabs.split(',').indexOf('GraphsPage')) {
      setData();
    }
  }

  Future<void> showHistory() async {
    final exerciseSets = bodyWeight
        ? await getBodyWeightGraphHistory()
        : await getGraphHistory(exerciseName);
    if (!mounted) return;

    final desktop = isDesktopLayout(context);
    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => GraphHistoryPage(
          name: exerciseName,
          initialSets: exerciseSets,
          tabController: tabController,
          bodyWeight: bodyWeight,
        ),
      ),
    );
    if (!mounted) return;
    _refreshTimer?.cancel();
    if (desktop) {
      setData();
    } else {
      _refreshTimer = Timer(kThemeAnimationDuration, setData);
    }
  }

  void showOptions() {
    final settings = context.read<Setting>();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            void refreshSheet() => setSheet(() {});

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: GraphOptionsControls(
                  compact: false,
                  shortDateFormat: settings.shortDateFormat,
                  unitValue: optionsUnits.isNotEmpty ? targetUnit : null,
                  unitItems: optionsUnits,
                  onUnitChanged: (value) {
                    if (!mounted) return;
                    setState(() {
                      targetUnit = value;
                    });
                    setData();
                    refreshSheet();
                  },
                  startDate: start,
                  endDate: end,
                  onSelectStart: () async {
                    if (!mounted) return;
                    await selectStart();
                    if (sheetContext.mounted) refreshSheet();
                  },
                  onClearStart: () {
                    if (!mounted) return;
                    setState(() {
                      start = null;
                    });
                    setData();
                    refreshSheet();
                  },
                  onSelectEnd: () async {
                    if (!mounted) return;
                    await selectEnd();
                    if (sheetContext.mounted) refreshSheet();
                  },
                  onClearEnd: () {
                    if (!mounted) return;
                    setState(() {
                      end = null;
                    });
                    setData();
                    refreshSheet();
                  },
                  limit: limit,
                  maxLimit: 100,
                  onLimitChanged: (value) {
                    if (!mounted) return;
                    setState(() {
                      limit = value;
                    });
                    setData();
                    savePreferences();
                    refreshSheet();
                  },
                  timeBasedXAxis: timeAxis,
                  onTimeAxisChange: (value) {
                    if (!mounted) return;
                    setState(() {
                      timeAxis = value;
                    });
                    savePreferences();
                    refreshSheet();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> touchLine(int index) async {
    if (DateTime.now().difference(lastTap) >=
        const Duration(milliseconds: 300)) {
      lastTap = DateTime.now();
      return;
    }

    if (bodyWeight) return;
    final created = pointDate(index);
    if (created == null) return;
    final desktop = isDesktopLayout(context);
    final exerciseSet = await getGraphPointSet(exerciseName, created);
    if (!mounted || exerciseSet == null) return;

    await Navigator.of(context).push(
      FlexPageRoute(
        builder: (context) => EditSetPage(exerciseSet: exerciseSet),
      ),
    );
    _refreshTimer?.cancel();
    if (desktop) {
      setData();
    } else {
      _refreshTimer = Timer(kThemeAnimationDuration, setData);
    }
  }

  Future<void> selectEnd() async {
    if (!mounted) return;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      end = pickedDate;
    });
    setData();
  }

  Future<void> selectStart() async {
    if (!mounted) return;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      start = pickedDate;
    });
    setData();
  }
}
