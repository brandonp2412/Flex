double displayLoad(String unit, double? loadKg) {
  if (loadKg == null) return 0;
  return switch (unit) {
    'lb' => loadKg / 0.45359237,
    'stone' => loadKg / 6.35029318,
    _ => loadKg,
  };
}

double? loadKg(String unit, double value) {
  return switch (unit) {
    'kg' => value,
    'lb' => value * 0.45359237,
    'stone' => value * 6.35029318,
    _ => null,
  };
}
