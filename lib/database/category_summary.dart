import 'package:flex/database/database.dart';

/// A category and the number of workout entries currently using it.
class CategorySummary {
  const CategorySummary({required this.category, required this.usageCount});

  final Category category;
  final int usageCount;
}
