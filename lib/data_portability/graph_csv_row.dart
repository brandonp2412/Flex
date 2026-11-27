import 'package:flex/data_portability/graph_csv.dart';
import 'package:flex/data_portability/graph_csv_import_exception.dart';
import 'package:flex/utils.dart';

final class GraphCsvRow {
  GraphCsvRow(List<String> header, List<dynamic> values)
    : _values = {
        for (var index = 0; index < header.length; index++)
          header[index]: index < values.length ? values[index] : null,
      };

  final Map<String, dynamic> _values;

  bool has(String key) => _values.containsKey(key);

  String string(String key, {bool required = false, String fallback = ''}) {
    final value = _values[key];
    if (value == null || value.toString().trim().isEmpty) {
      if (required) throw GraphCsvImportException('Missing $key.');
      return fallback;
    }
    return value.toString().trim();
  }

  String? nullableString(String key) {
    final value = string(key);
    return value.isEmpty ? null : value;
  }

  double? number(String key, {bool required = false}) {
    final value = _values[key];
    if (value == null || value.toString().trim().isEmpty) {
      if (required) throw GraphCsvImportException('Missing $key.');
      return null;
    }
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    if (parsed == null) {
      throw GraphCsvImportException('Invalid number for $key: $value.');
    }
    return parsed;
  }

  int? integer(String key, {bool required = false}) {
    final value = number(key, required: required);
    if (value == null) return null;
    if (value % 1 != 0) {
      throw GraphCsvImportException('Invalid integer for $key: $value.');
    }
    return value.toInt();
  }

  bool boolean(String key) {
    final value = _values[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  DateTime? date(String key, {bool required = false}) {
    final value = _values[key];
    if (value == null || value.toString().trim().isEmpty) {
      if (required) throw GraphCsvImportException('Missing $key.');
      return null;
    }
    try {
      return parseDate(value.toString());
    } on FormatException {
      throw GraphCsvImportException('Invalid date for $key: $value.');
    }
  }
}
