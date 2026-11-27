import 'package:drafter/painting.dart';

class FlexLineChartScale extends CartesianScale {
  final Map<int, double> _xByIndex;

  FlexLineChartScale({
    required super.bounds,
    required super.count,
    required super.minValue,
    required super.maxValue,
    required Map<int, double> xByIndex,
  }) : _xByIndex = Map.unmodifiable(xByIndex);

  @override
  double xForIndex(int index) => _xByIndex[index] ?? super.xForIndex(index);

  @override
  int nearestIndex(double px) {
    if (_xByIndex.isEmpty || !px.isFinite) return super.nearestIndex(px);

    var nearest = _xByIndex.keys.first;
    var nearestDistance = (_xByIndex[nearest]! - px).abs();
    for (final entry in _xByIndex.entries.skip(1)) {
      final distance = (entry.value - px).abs();
      if (distance < nearestDistance) {
        nearest = entry.key;
        nearestDistance = distance;
      }
    }
    return nearest;
  }
}
