abstract class GraphData {
  const GraphData({
    required this.created,
    required this.value,
    required this.unit,
  });

  final DateTime created;
  final double value;
  final String unit;
}
