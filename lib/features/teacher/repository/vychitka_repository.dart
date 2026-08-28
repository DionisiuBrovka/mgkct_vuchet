import '../../../core/pocket_base_service.dart';
import '../models/assignment.dart';
import '../models/vychitka_entry.dart';
import '../models/zamena.dart';

class VychitkaRepository {
  VychitkaRepository(this._pb);

  final PocketBaseService _pb;

  Future<List<Assignment>> getAssignments(String teacher, int year) =>
      _pb.getAssignments(teacher, year);

  Future<List<VychitkaEntry>> getEntries(
    String teacher,
    String month,
    int year,
  ) =>
      _pb.getVychitki(teacher: teacher, month: month, year: year);

  /// Статусы всех месяцев учебного года (один запрос вместо 11).
  Future<Map<String, VychitkaStatus>> getMonthStatusesForYear(
    String teacher,
    int academicYearStart,
  ) =>
      _pb.getMonthStatusesForYear(teacher, academicYearStart);

  Future<List<VychitkaEntry>> saveOrUpdateEntries(
          List<VychitkaEntry> entries) =>
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

  Future<List<Zamena>> getZameny(String teacher, String month, int year) =>
      _pb.getZameny(teacher, month, year);

  Future<void> saveZamena(Zamena z) => _pb.saveZamena(z);

  Future<void> deleteZamena(
    String teacher,
    String month,
    int year,
    String date,
  ) =>
      _pb.deleteZamena(teacher, month, year, date);

  Future<List<String>> getAllTeacherNames() async {
    final users = await _pb.getAllUsers();
    return users.map((u) => u.name).toList();
  }

  Future<Map<String, VychitkaStatus>> getMonthStatusesForAll(
    String month,
    int year,
  ) async {
    final entries = await _pb.getVychitki(month: month, year: year);
    final map = <String, VychitkaStatus>{};
    for (final e in entries) {
      final existing = map[e.teacher];
      if (e.teacher.isEmpty) continue;
      if (existing == null ||
          e.status.index > existing.index) {
        map[e.teacher] = e.status;
      }
    }
    return map;
  }
}
