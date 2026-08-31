import 'package:freezed_annotation/freezed_annotation.dart';

part 'teaching_report_entry.freezed.dart';

enum TeachingReportStatus { draft, submitted, confirmed }

@freezed
class TeachingReportEntry with _$TeachingReportEntry {
  const TeachingReportEntry._();

  const factory TeachingReportEntry({
    required String id,
    required String teacher,
    required String month,
    required int year,
    required String subject,
    required String group,
    @Default('') String assignmentId,
    @Default(0) double lectureHours,
    @Default(0) double practicalHours,
    @Default(0) double courseProjectHours,
    @Default(0) double consultationHours,
    @Default(0) double additionalAssessmentHours,
    @Default(0) double examHours,
    @Default(TeachingReportStatus.draft) TeachingReportStatus status,
    DateTime? submittedAt,
    DateTime? confirmedAt,
    String? confirmedBy,
  }) = _TeachingReportEntry;

  double get totalHours =>
      lectureHours +
      practicalHours +
      courseProjectHours +
      consultationHours +
      additionalAssessmentHours +
      examHours;
}
