const weightUnitFactors = {'kg': 1.0, 'lb': 0.45359237, 'stone': 6.35029318};
const distanceUnitFactors = {
  'm': 1.0,
  'km': 1000.0,
  'mi': 1609.344,
  'kcal': 1.0,
};

double displayLoad(String unit, double? loadKg) =>
    (loadKg ?? 0) / (weightUnitFactors[unit] ?? 1);

double? loadKg(String unit, double value) =>
    weightUnitFactors[unit] == null ? null : value * weightUnitFactors[unit]!;

double displayDistance(String unit, double? distanceMetres) =>
    (distanceMetres ?? 0) / (distanceUnitFactors[unit] ?? 1);

double? distanceMetres(String unit, double value) =>
    distanceUnitFactors[unit] == null
    ? null
    : value * distanceUnitFactors[unit]!;

double estimateOneRepMax(double weight, double reps) {
  final factor = 1.0278 - 0.0278 * reps;
  if (factor == 0) return 0;
  return weight >= 0 ? weight / factor : weight * factor;
}
