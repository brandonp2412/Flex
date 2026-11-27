import 'package:flex/database/previous_exercise_set.dart';

class PreviousExerciseDay {
  const PreviousExerciseDay({required this.day, required this.sets});

  final DateTime day;
  final List<PreviousExerciseSet> sets;
}
