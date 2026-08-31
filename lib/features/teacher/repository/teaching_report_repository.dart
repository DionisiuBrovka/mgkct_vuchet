import '../../../core/pocket_base_service.dart';
import '../models/assignment.dart';
import '../models/teaching_report_entry.dart';
import '../models/substitution.dart';

class TeachingReportRepository {
  TeachingReportRepository(this._pb);

  final PocketBaseService _pb;

  Future<List<Assignment>> getAssignments(String teacher, int year) =>
      _pb.getAssignments(teacher, year);

  Future<List<TeachingReportEntry>> getEntries(
    String teacher,
    String month,
    int year,
  ) =>
      _pb.getTeachingReportEntries(teacher: teacher, month: month, year: year);

  /// Статусы всех месяцев учебного года (один запрос вместо 11).
  Future<Map<String, TeachingReportStatus>> getMonthStatusesForYear(
    String teacher,
    int academicYearStart,
  ) =>
      _pb.getMonthStatusesForYear(teacher, academicYearStart);

  Future<List<TeachingReportEntry>> saveOrUpdateEntries(
          List<TeachingReportEntry> entries) =>
      _pb.saveEntries(entries);

  Future<void> submitMonth(String teacher, String month, int year) =>
      _pb.submitMonth(teacher, month, year);

  Future<void> confirmMonth(
    String teacher,
    String month,
    int year,
    String confirmedBy,
  ) =>
      _pb.confirmMonth(teacher, month, year, confirmedBy);

  Future<void> rejectMonth(String teacher, String month, int year) =>
      _pb.rejectMonth(teacher, month, year);

  Future<List<Substitution>> getSubstitutions(
          String teacher, String month, int year) =>
      _pb.getSubstitutions(teacher, month, year);

  Future<void> saveSubstitution(Substitution substitution) =>
      _pb.saveSubstitution(substitution);

  Future<void> deleteSubstitution(
    String teacher,
    String month,
    int year,
    String date,
  ) =>
      _pb.deleteSubstitution(teacher, month, year, date);

  Future<List<String>> getAllTeacherNames() async {
    final users = await _pb.getAllUsers();
    return users.map((u) => u.name).toList();
  }

  Future<Map<String, TeachingReportStatus>> getMonthStatusesForAll(
    String month,
    int year,
  ) async {
    final entries =
        await _pb.getTeachingReportEntries(month: month, year: year);
    final map = <String, TeachingReportStatus>{};
    for (final e in entries) {
      final existing = map[e.teacher];
      if (e.teacher.isEmpty) continue;
      if (existing == null || e.status.index > existing.index) {
        map[e.teacher] = e.status;
      }
    }
    return map;
  }
}
