import 'package:flex/database/database.dart';

class PlanExerciseDraft {
  PlanExerciseDraft({required this.planExercise, required this.exerciseName})
    : nameLower = exerciseName.toLowerCase();

  final PlanExercisesCompanion planExercise;
  final String exerciseName;
  final String nameLower;

  PlanExerciseDraft copyWithPlanExercise(PlanExercisesCompanion value) =>
      PlanExerciseDraft(planExercise: value, exerciseName: exerciseName);
}
