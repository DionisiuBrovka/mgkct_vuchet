import 'package:flutter_test/flutter_test.dart';
import 'package:mgkct_teaching_hours/core/domain.dart';

void main() {
  test('decimal strings retain exact canonical values', () {
    expect(
        DecimalValue.parse('0.123456789012345678901234567890123456789').value,
        '0.123456789012345678901234567890123456789');
    expect(() => DecimalValue.parse(0.1), throwsFormatException);
    expect(() => DecimalValue.parse('1e3'), throwsFormatException);
  });
  test('report DTO rejects unknown enum and preserves strings', () {
    final report = ReportDto.fromJson({
      'id': null,
      'teacher': {'id': 'teacher'},
      'period': {'year': 2026, 'month': 9},
      'status': 'draft',
      'revision': 0,
      'entries': [],
      'substitutions': [],
      'totals': {
        'lectureHours': '0.1',
        'practicalHours': '0',
        'courseProjectHours': '0',
        'consultationHours': '0',
        'additionalAssessmentHours': '0',
        'examHours': '0',
        'assignmentTotal': '0.1',
        'substitutionTotal': '0',
        'grandTotal': '0.1'
      }
    });
    expect(report.totals['grandTotal'].toString(), '0.1');
    expect(() => ReportStatus.values.byName('other'), throwsArgumentError);
  });
}
