import 'package:flex/data_portability/external_workout_import_exception.dart';

final class CsvRecord {
  CsvRecord(this.line, List<String> header, List<dynamic> values)
    : fields = {
        for (var i = 0; i < header.length; i++)
          header[i]: i < values.length ? values[i].toString().trim() : '',
      };

  final int line;
  final Map<String, String> fields;

  String get(String name) => fields[name.toLowerCase()] ?? '';

  String require(String name) {
    final value = get(name);
    if (value.isEmpty) {
      throw ExternalWorkoutImportException('Row $line: missing $name.');
    }
    return value;
  }

  double? number(String name) {
    final value = get(name);
    if (value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      throw ExternalWorkoutImportException(
        'Row $line: invalid $name ($value).',
      );
    }
    return parsed;
  }

  DateTime date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw ExternalWorkoutImportException('Row $line: invalid date ($value).');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      date.millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: date.isUtc,
    );
  }
}
