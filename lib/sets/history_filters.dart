import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';

class HistoryFilters {
  final repsGt = TextEditingController();
  final repsLt = TextEditingController();
  final weightGt = TextEditingController();
  final weightLt = TextEditingController();
  DateTime? startDate, endDate;
  String? category;

  Iterable<TextEditingController> get _controllers => [
    repsGt,
    repsLt,
    weightGt,
    weightLt,
  ];

  int get count =>
      [startDate, endDate, category].nonNulls.length +
      _controllers.where((controller) => controller.text.isNotEmpty).length;

  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    startDate = endDate = null;
    category = null;
  }

  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
  }

  ExerciseSetQuery query(
    AppDatabase database,
    BuildContext context, {
    required String search,
    int? limit,
  }) => ExerciseSetQuery(
    database,
    search: search,
    category: category,
    startDate: startDate,
    endDate: endDate,
    repsGt: parseDisplayNumber(context, repsGt.text),
    repsLt: parseDisplayNumber(context, repsLt.text),
    weightGt: parseDisplayNumber(context, weightGt.text),
    weightLt: parseDisplayNumber(context, weightLt.text),
    limit: limit,
  );
}
