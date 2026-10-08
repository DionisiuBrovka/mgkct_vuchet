import '../../../core/decimal_input.dart';
import '../../../core/domain.dart';
import 'package:uuid/uuid.dart';

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
        },
        substitutions = [
          for (final item in report.substitutions)
            EditableSubstitution.fromDto(item),
        ];

  EditableReport._(this.report, this.values, this.substitutions);

  final ReportDto report;
  final Map<String, Map<String, String>> values;
  final List<EditableSubstitution> substitutions;

  EditableReport copy() => EditableReport._(report, {
        for (final entry in values.entries) entry.key: {...entry.value}
      }, [
        for (final item in substitutions) item.copy()
      ]);

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
    return null;
  }

  DecimalInput totalFor(EntryDto entry) => hourKeys.fold(
      DecimalInput.tryParse('0')!,
      (total, field) =>
          total +
          (parsed(entry.assignment.id, field) ?? DecimalInput.tryParse('0')!));

  DecimalInput categoryFor(EntryDto entry, {required bool additional}) =>
      hourKeys
          .where(
              (field) => (field == 'additionalAssessmentHours') == additional)
          .fold(
              DecimalInput.tryParse('0')!,
              (total, field) =>
                  total +
                  (parsed(entry.assignment.id, field) ??
                      DecimalInput.tryParse('0')!));

  DecimalInput get assignmentTotal => report.entries.fold(
      DecimalInput.tryParse('0')!, (total, entry) => total + totalFor(entry));

  DecimalInput get substitutionTotal => substitutions.fold(
      DecimalInput.tryParse('0')!,
      (total, substitution) =>
          total +
          (DecimalInput.tryParse(substitution.hours) ??
              DecimalInput.tryParse('0')!));

  DecimalInput get grandTotal => assignmentTotal + substitutionTotal;

  Map<String, dynamic>? input() {
    for (final entry in report.entries) {
      for (final field in hourKeys) {
        if (validation(entry.assignment.id, field) != null) return null;
      }
    }
    for (final substitution in substitutions) {
      final hours = DecimalInput.tryParse(substitution.hours);
      if (substitution.date.isEmpty ||
          substitution.description.trim().isEmpty ||
          hours == null) {
        return null;
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
        for (final substitution in substitutions)
          {
            'id': substitution.id,
            'date': substitution.date,
            'description': substitution.description,
            'hours': DecimalInput.tryParse(substitution.hours)!.canonical,
          },
      ],
    };
  }
}

class EditableSubstitution {
  EditableSubstitution({
    this.id,
    String? key,
    required this.date,
    required this.description,
    required this.hours,
  }) : key = key ?? 'local:${const Uuid().v4()}';
  factory EditableSubstitution.fromDto(SubstitutionDto value) =>
      EditableSubstitution(
          id: value.id,
          date: value.date,
          description: value.description,
          hours: value.hours.value);
  final String? id;
  final String key;
  String date, description, hours;
  EditableSubstitution copy() => EditableSubstitution(
      id: id, key: key, date: date, description: description, hours: hours);
}
