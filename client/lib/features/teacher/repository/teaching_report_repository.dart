import '../../../core/api_service.dart';
import '../models/report_snapshot.dart';
import '../models/teaching_report_entry.dart';

class TeachingReportRepository {
  TeachingReportRepository(this._api);
  final ApiService _api;
  Future<ReportSnapshot> getReport(
          String teacher, String month, int year) async =>
      ReportSnapshot.fromJson(
          await _api.request('GET', ['reports', teacher, '$year', month])
              as Map<String, dynamic>);
  Future<ReportSnapshot> change(ReportSnapshot report, String action) async =>
      ReportSnapshot.fromJson(await _api.request('POST',
          ['reports', report.teacher, '${report.year}', report.month, action],
          body: action == 'save' || action == 'submit'
              ? report.toInput()
              : {'revision': report.revision}) as Map<String, dynamic>);
  Future<Map<String, TeachingReportStatus>> getMonthStatusesForYear(
      String teacher, int year) async {
    final json =
        await _api.request('GET', ['teachers', teacher, 'years', '$year'])
            as Map<String, dynamic>;
    return json.map((key, value) =>
        MapEntry(key, TeachingReportStatus.values.byName(value as String)));
  }

  Future<List<TeacherSummary>> overview(String month, int year) async {
    final rows =
        await _api.request('GET', ['admin', 'months', '$year', month]) as List;
    return [
      for (final row in rows)
        TeacherSummary(row['id'] as String, row['name'] as String,
            TeachingReportStatus.values.byName(row['status'] as String))
    ];
  }
}
