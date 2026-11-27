import 'package:flex/graph/graph_data.dart';

class StrengthData extends GraphData {
  final double reps;
  final String? category;

  StrengthData({
    required super.created,
    required super.unit,
    required super.value,
    required this.reps,
    this.category,
  });
}

typedef StrengthDataLookupKey = ({String? category, DateTime created});

Map<StrengthDataLookupKey, StrengthData> indexStrengthDataByCategoryAndDate(
  Iterable<StrengthData> data,
) => {
  for (final row in data) (category: row.category, created: row.created): row,
};

Map<String?, List<StrengthData>> groupStrengthDataByCategory(
  Iterable<StrengthData> data,
) {
  final grouped = <String?, List<StrengthData>>{};
  for (final row in data) {
    (grouped[row.category] ??= <StrengthData>[]).add(row);
  }
  return grouped;
}
