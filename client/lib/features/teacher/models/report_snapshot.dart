import 'substitution.dart';
import 'teaching_report_entry.dart';

class ReportSnapshot {
  const ReportSnapshot(
      {required this.teacher,
      required this.teacherName,
      required this.month,
      required this.year,
      required this.revision,
      required this.status,
      required this.entries,
      required this.substitutions,
      required this.totals});
  final String teacher;
  final String teacherName;
  final String month;
  final int year;
  final int revision;
  final TeachingReportStatus status;
  final List<TeachingReportEntry> entries;
  final List<Substitution> substitutions;
  final Map<String, num> totals;

  factory ReportSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic value) =>
        value is String ? DateTime.tryParse(value) : null;
    double hours(Map<String, dynamic> row, String key) =>
        (row[key] as num).toDouble();
    return ReportSnapshot(
        teacher: json['teacher'] as String,
        teacherName: json['teacherName'] as String,
        month: json['month'] as String,
        year: json['year'] as int,
        revision: json['revision'] as int,
        status: TeachingReportStatus.values.byName(json['status'] as String),
        totals: Map<String, num>.from(json['totals'] as Map),
        entries: (json['entries'] as List).map((value) {
          final row = value as Map<String, dynamic>;
          return TeachingReportEntry(
              id: row['id'] as String,
              assignmentId: row['assignmentId'] as String,
              teacher: json['teacher'] as String,
              month: json['month'] as String,
              year: json['year'] as int,
              subject: row['subject'] as String,
              group: row['group'] as String,
              lectureHours: hours(row, 'lectureHours'),
              practicalHours: hours(row, 'practicalHours'),
              courseProjectHours: hours(row, 'courseProjectHours'),
              consultationHours: hours(row, 'consultationHours'),
              additionalAssessmentHours:
                  hours(row, 'additionalAssessmentHours'),
              examHours: hours(row, 'examHours'),
              status:
                  TeachingReportStatus.values.byName(json['status'] as String),
              submittedAt: date(row['submittedAt']),
              confirmedAt: date(row['confirmedAt']),
              confirmedBy: row['confirmedBy'] as String?);
        }).toList(),
        substitutions: (json['substitutions'] as List).map((value) {
          final row = value as Map<String, dynamic>;
          return Substitution(
              id: row['id'] as String,
              teacher: json['teacher'] as String,
              month: json['month'] as String,
              year: json['year'] as int,
              group: row['group'] as String,
              date: row['date'] as String,
              hours: hours(row, 'hours'));
        }).toList());
  }
  ReportSnapshot copyWith(
          {List<TeachingReportEntry>? entries,
          List<Substitution>? substitutions}) =>
      ReportSnapshot(
          teacher: teacher,
          teacherName: teacherName,
          month: month,
          year: year,
          revision: revision,
          status: status,
          entries: entries ?? this.entries,
          substitutions: substitutions ?? this.substitutions,
          totals: totals);
  Map<String, dynamic> toInput() => {
        'revision': revision,
        'entries': [
          for (final e in entries)
            {
              'assignmentId': e.assignmentId,
              'lectureHours': e.lectureHours,
              'practicalHours': e.practicalHours,
              'courseProjectHours': e.courseProjectHours,
              'consultationHours': e.consultationHours,
              'additionalAssessmentHours': e.additionalAssessmentHours,
              'examHours': e.examHours
            }
        ],
        'substitutions': [
          for (final s in substitutions)
            {'id': s.id, 'group': s.group, 'date': s.date, 'hours': s.hours}
        ]
      };
}

class TeacherSummary {
  const TeacherSummary(this.id, this.name, this.status);
  final String id;
  final String name;
  final TeachingReportStatus status;
}
