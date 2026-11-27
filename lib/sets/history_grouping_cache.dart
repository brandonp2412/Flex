import 'package:flex/database/database.dart';
import 'package:flex/sets/history_page.dart';

class HistoryGroupingCache {
  List<ExerciseSetView>? _source;
  List<HistoryDayGroup>? _groups;

  List<HistoryDayGroup> get(List<ExerciseSetView> sets) {
    if (identical(_source, sets)) return _groups!;
    _source = sets;
    return _groups = getHistoryDayGroups(sets);
  }
}
