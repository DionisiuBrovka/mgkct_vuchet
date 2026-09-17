enum UserRole { teacher, admin }

enum ReportStatus { draft, submitted, confirmed }

class ApiUser {
  const ApiUser({required this.id, required this.name, required this.role});
  final String id, name;
  final UserRole role;
  factory ApiUser.fromJson(Map<String, dynamic> value) => ApiUser(
      id: _string(value, 'id'),
      name: _string(value, 'name'),
      role: UserRole.values.byName(_string(value, 'role')));
}

class DecimalValue {
  const DecimalValue(this.value);
  final String value;
  static final _valid = RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$');
  factory DecimalValue.parse(Object? value) {
    if (value is! String || !_valid.hasMatch(value)) {
      throw const FormatException('decimal');
    }
    return DecimalValue(value);
  }
  @override
  String toString() => value;
}

class AssignmentDto {
  const AssignmentDto(
      {required this.id, required this.subject, required this.group});
  final String id, subject, group;
  factory AssignmentDto.fromJson(Map<String, dynamic> v) => AssignmentDto(
      id: _string(v, 'id'),
      subject: _string(v, 'subject'),
      group: _string(v, 'group'));
}

class EntryDto {
  const EntryDto(
      {required this.id,
      required this.assignment,
      required this.hours,
      required this.total});
  final String? id;
  final AssignmentDto assignment;
  final Map<String, DecimalValue> hours;
  final DecimalValue total;
  factory EntryDto.fromJson(Map<String, dynamic> v) {
    const keys = [
      'lectureHours',
      'practicalHours',
      'courseProjectHours',
      'consultationHours',
      'additionalAssessmentHours',
      'examHours'
    ];
    return EntryDto(
        id: v['id'] as String?,
        assignment: AssignmentDto.fromJson(_map(v, 'assignment')),
        hours: {for (final key in keys) key: DecimalValue.parse(v[key])},
        total: DecimalValue.parse(v['totalHours']));
  }
}

class SubstitutionDto {
  const SubstitutionDto(
      {required this.id,
      required this.date,
      required this.description,
      required this.hours});
  final String? id;
  final String date, description;
  final DecimalValue hours;
  factory SubstitutionDto.fromJson(Map<String, dynamic> v) => SubstitutionDto(
      id: v['id'] as String?,
      date: _string(v, 'date'),
      description: _string(v, 'description'),
      hours: DecimalValue.parse(v['hours']));
}

class ReportDto {
  const ReportDto(
      {required this.id,
      required this.teacher,
      required this.year,
      required this.month,
      required this.status,
      required this.revision,
      required this.entries,
      required this.substitutions,
      required this.totals});
  final String? id;
  final ApiUser teacher;
  final int year, month, revision;
  final ReportStatus status;
  final List<EntryDto> entries;
  final List<SubstitutionDto> substitutions;
  final Map<String, DecimalValue> totals;
  factory ReportDto.fromJson(Map<String, dynamic> v) {
    final period = _map(v, 'period');
    final teacher = _map(v, 'teacher');
    final totals = _map(v, 'totals');
    return ReportDto(
        id: v['id'] as String?,
        teacher: ApiUser(
            id: _string(teacher, 'id'),
            name: (teacher['name'] as String?) ?? '',
            role: UserRole.teacher),
        year: _int(period, 'year'),
        month: _int(period, 'month'),
        status: ReportStatus.values.byName(_string(v, 'status')),
        revision: _int(v, 'revision'),
        entries: [
          for (final row in _list(v, 'entries'))
            EntryDto.fromJson(_mapValue(row))
        ],
        substitutions: [
          for (final row in _list(v, 'substitutions'))
            SubstitutionDto.fromJson(_mapValue(row))
        ],
        totals: {
          for (final entry in totals.entries)
            entry.key: DecimalValue.parse(entry.value)
        });
  }
}

class AdminTeacherDto {
  const AdminTeacherDto(
      {required this.id, required this.name, required this.status});
  final String id, name;
  final ReportStatus status;
  factory AdminTeacherDto.fromJson(Map<String, dynamic> value) =>
      AdminTeacherDto(
          id: _string(value, 'id'),
          name: _string(value, 'name'),
          status: ReportStatus.values.byName(_string(value, 'status')));
}

String _string(Map<String, dynamic> value, String key) {
  final x = value[key];
  if (x is! String) throw FormatException(key);
  return x;
}

int _int(Map<String, dynamic> value, String key) {
  final x = value[key];
  if (x is! int) throw FormatException(key);
  return x;
}

Map<String, dynamic> _map(Map<String, dynamic> value, String key) =>
    _mapValue(value[key]);
Map<String, dynamic> _mapValue(Object? value) =>
    Map<String, dynamic>.from(value as Map);
List _list(Map<String, dynamic> value, String key) => value[key] as List;
