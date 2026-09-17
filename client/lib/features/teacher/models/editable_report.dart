import '../../../core/decimal_input.dart';
import '../../../core/domain.dart';

const hourKeys = [
  'lectureHours',
  'practicalHours',
  'courseProjectHours',
  'consultationHours',
  'additionalAssessmentHours',
  'examHours',
];

class EditableReport {
  EditableReport.fromReport(this.report)
      : values = {
          for (final entry in report.entries)
            entry.assignment.id: {
              for (final field in hourKeys) field: entry.hours[field]!.value,
            },
        };

  EditableReport._(this.report, this.values);

  final ReportDto report;
  final Map<String, Map<String, String>> values;

  EditableReport copy() => EditableReport._(report, {
        for (final entry in values.entries) entry.key: {...entry.value}
      });

  String value(String assignmentId, String field) =>
      values[assignmentId]![field]!;

  void setValue(String assignmentId, String field, String value) {
    values[assignmentId]![field] = value;
  }

  DecimalInput? parsed(String assignmentId, String field) =>
      DecimalInput.tryParse(value(assignmentId, field));

  String? validation(String assignmentId, String field) {
    final decimal = parsed(assignmentId, field);
    if (decimal == null) return 'Введите число';
    if (decimal.exceeds999) return 'Не больше 999';
    return null;
  }

  DecimalInput totalFor(EntryDto entry) => hourKeys.fold(
      DecimalInput.tryParse('0')!,
      (total, field) =>
          total +
          (parsed(entry.assignment.id, field) ?? DecimalInput.tryParse('0')!));

  DecimalInput get assignmentTotal => report.entries.fold(
      DecimalInput.tryParse('0')!, (total, entry) => total + totalFor(entry));

  DecimalInput get substitutionTotal => report.substitutions.fold(
      DecimalInput.tryParse('0')!,
      (total, substitution) =>
          total + DecimalInput.tryParse(substitution.hours.value)!);

  DecimalInput get grandTotal => assignmentTotal + substitutionTotal;

  Map<String, dynamic>? input() {
    for (final entry in report.entries) {
      for (final field in hourKeys) {
        if (validation(entry.assignment.id, field) != null) return null;
      }
    }
    return {
      'revision': report.revision,
      'entries': [
        for (final entry in report.entries)
          {
            'id': entry.id,
            'assignmentId': entry.assignment.id,
            for (final field in hourKeys)
              field: parsed(entry.assignment.id, field)!.canonical,
          },
      ],
      'substitutions': [
        for (final substitution in report.substitutions)
          {
            'id': substitution.id,
            'date': substitution.date,
            'description': substitution.description,
            'hours': substitution.hours.value,
          },
      ],
    };
  }
}
