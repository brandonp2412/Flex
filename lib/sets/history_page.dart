import 'package:flex/tab_navigator.dart';
import 'dart:collection';

import 'package:flex/database/database.dart';
import 'package:flex/sets/history_day.dart';
import 'package:flex/sets/history_day_group.dart';
import 'package:flex/sets/history_page_widget.dart';
import 'package:flutter/material.dart';

export 'package:flex/sets/history_day.dart';
export 'package:flex/sets/history_day_group.dart';
export 'package:flex/sets/history_grouping_cache.dart';

List<HistoryDayGroup> getHistoryDayGroups(List<ExerciseSetView> exerciseSets) {
  final groups = <HistoryDayGroup>[];
  int? lastDayKey;
  HistoryDayGroup? group;
  Map<String, HistoryDay>? exercises;
  for (final exerciseSet in exerciseSets) {
    final created = exerciseSet.created;
    final dayKey = created.year * 512 + created.month * 32 + created.day;
    if (dayKey != lastDayKey) {
      group = HistoryDayGroup(
        day: DateTime(created.year, created.month, created.day),
        exercises: [],
      );
      groups.add(group);
      exercises = HashMap<String, HistoryDay>();
      lastDayKey = dayKey;
    }
    final name = exerciseSet.name;
    var exercise = exercises![name];
    if (exercise == null) {
      exercise = HistoryDay(name: name, exerciseSets: [], day: group!.day);
      exercises[name] = exercise;
      group.exercises.add(exercise);
    }
    exercise.exerciseSets.add(exerciseSet);
  }
  return groups;
}

class HistoryPage extends StatefulWidget {
  final TabController tabController;

  const HistoryPage({super.key, required this.tabController});

  @override
  createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return tabNavigator(
      context,
      navigatorKey: _navKey,
      tabName: 'HistoryPage',
      tabController: widget.tabController,
      builder: (context) => HistoryPageWidget(navigatorKey: _navKey),
    );
  }
}
