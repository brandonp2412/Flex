import 'package:flex/database/exercise_set_view.dart';

class HistoryDay {
  final String name;
  final List<ExerciseSetView> exerciseSets;
  final DateTime day;

  HistoryDay({
    required this.name,
    required this.exerciseSets,
    required this.day,
  });
}
