import 'dart:typed_data';
import 'api_service.dart';
import 'domain.dart';

class ReportRepository {
  ReportRepository(this._api);
  final ApiService _api;
  Future<Map<String, dynamic>> statisticsOptions() async =>
      Map<String, dynamic>.from(
          await _api.request('GET', ['admin', 'statistics', 'options']) as Map);
  Future<Map<String, dynamic>> statistics(Map<String, String> filters) async =>
      Map<String, dynamic>.from(await _api
          .request('GET', ['admin', 'statistics'], query: filters) as Map);
  Future<Uint8List> exportStatistics(Map<String, String> filters) =>
      _api.download(['admin', 'statistics.xlsx'], filters);
  Future<ReportDto> report(String teacherId, int year, int month) async =>
      ReportDto.fromJson(
          await _api.request('GET', ['reports', teacherId, '$year', '$month'])
              as Map<String, dynamic>);
  Future<ReportDto> save(
          int year, int month, Map<String, dynamic> input) async =>
      ReportDto.fromJson(await _api.request(
              'PUT', ['teacher', 'reports', '$year', '$month'], body: input)
          as Map<String, dynamic>);
  Future<ReportDto> submit(
          int year, int month, Map<String, dynamic> input) async =>
      ReportDto.fromJson(await _api.request(
          'POST', ['teacher', 'reports', '$year', '$month', 'submit'],
          body: input) as Map<String, dynamic>);
  Future<ReportDto> transition(String teacher, int year, int month,
          int revision, String action) async =>
      ReportDto.fromJson(await _api.request(
          'POST', ['admin', 'reports', teacher, '$year', '$month', action],
          body: {'revision': revision}) as Map<String, dynamic>);
  Future<List<Map<String, dynamic>>> teacherPeriods() async =>
      List<Map<String, dynamic>>.from(
          (await _api.request('GET', ['teacher', 'periods'])
              as Map<String, dynamic>)['periods'] as List);
  Future<List<Map<String, dynamic>>> adminPeriods() async =>
      List<Map<String, dynamic>>.from(
          (await _api.request('GET', ['admin', 'periods'])
              as Map<String, dynamic>)['periods'] as List);
  Future<List<AdminTeacherDto>> adminReports(int year, int month,
      {String? query, ReportStatus? status}) async {
    final rows = List<Map<String, dynamic>>.from((await _api.request('GET', [
      'admin',
      'reports'
    ], query: {
      'year': '$year',
      'month': '$month',
      if (query != null) 'q': query,
      if (status != null) 'status': status.name
    }) as Map<String, dynamic>)['teachers'] as List);
    return [for (final row in rows) AdminTeacherDto.fromJson(row)];
  }
}
