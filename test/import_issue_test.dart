import 'package:flex/data_portability/import_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short errors preserve diagnostics in email', () {
    final url = buildImportReportEmail(
      kind: 'database',
      error: StateError('Could not open backup'),
      stackTrace: StackTrace.fromString('frame one\nframe two'),
      version: '2.2.34',
    );
    expect(url.scheme, 'mailto');
    expect(url.path, 'brandon@presley.nz');
    expect(url.query, isNot(contains('+')));
    expect(url.queryParameters['subject'], 'Import failed: database');
    expect(url.queryParameters['body'], contains('Could not open backup'));
    expect(url.queryParameters['body'], contains('frame one'));
    expect(url.queryParameters['body'], contains('2.2.34'));
  });

  test('oversized error and stack do not create rejected URLs', () {
    final url = buildImportReportEmail(
      kind: 'plans',
      error: Exception(List.filled(3000, '🚨').join()),
      stackTrace: StackTrace.fromString(List.filled(5000, '⚠️').join()),
      version: '2.2.34',
    );
    expect(url.toString().length, lessThanOrEqualTo(1800));
    expect(url.queryParameters['subject'], 'Import failed: plans');
    expect(url.queryParameters['body'], contains('2.2.34'));
  });
}
