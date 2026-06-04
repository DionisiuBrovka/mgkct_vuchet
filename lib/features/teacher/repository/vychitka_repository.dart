import '../../../core/sheets_service.dart';
import '../models/assignment.dart';
import '../models/vychitka_entry.dart';
import '../models/zamena.dart';

class VychitkaRepository {
  VychitkaRepository(this._sheets);

  final SheetsService _sheets;

  Future<List<Assignment>> getAssignments(String teacher, int year) =>
      _sheets.getAssignments(teacher, year);

  Future<VychitkaStatus> getMonthStatus(
    String teacher,
    String month,
    int year,
  ) async {
    final entries =
        await _sheets.getVychitki(teacher: teacher, month: month, year: year);
    if (entries.isEmpty) return VychitkaStatus.draft;
    // All entries in a month share the same status — use first
    return entries.first.status;
  }

  Future<List<VychitkaEntry>> getEntries(
    String teacher,
    String month,
    int year,
  ) =>
      _sheets.getVychitki(teacher: teacher, month: month, year: year);

  Future<void> saveOrUpdateEntries(List<VychitkaEntry> entries) async {
    for (final e in entries) {
      await _sheets.updateEntry(e);
    }
  }

  Future<void> submitMonth(String teacher, String month, int year) =>
      _sheets.submitMonth(teacher, month, year);

  Future<void> confirmMonth(
    String teacher,
    String month,
    int year,
    String confirmedBy,
  ) =>
      _sheets.confirmMonth(teacher, month, year, confirmedBy);

  Future<void> rejectMonth(String teacher, String month, int year) =>
      _sheets.rejectMonth(teacher, month, year);

  Future<List<Zamena>> getZameny(String teacher, String month, int year) =>
      _sheets.getZameny(teacher, month, year);

  Future<void> saveZamena(Zamena z) => _sheets.saveZamena(z);

  Future<void> deleteZamena(
    String teacher,
    String month,
    int year,
    String date,
  ) =>
      _sheets.deleteZamena(teacher, month, year, date);

  Future<List<String>> getAllTeacherNames() async {
    final users = await _sheets.getUsers();
    return users.map((u) => u.name).toList();
  }

  Future<Map<String, VychitkaStatus>> getMonthStatusesForAll(
    String month,
    int year,
  ) async {
    final entries =
        await _sheets.getVychitki(month: month, year: year);
    final map = <String, VychitkaStatus>{};
    for (final e in entries) {
      // Keep the "highest" status if duplicates
      final existing = map[e.teacher];
      if (existing == null ||
          e.status.index > existing.index) {
        map[e.teacher] = e.status;
      }
    }
    return map;
  }
}
