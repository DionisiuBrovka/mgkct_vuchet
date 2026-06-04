import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' hide Response;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../features/auth/models/app_user.dart';
import '../features/teacher/models/assignment.dart';
import '../features/teacher/models/vychitka_entry.dart';
import '../features/teacher/models/zamena.dart';
import 'constants.dart';

class SheetsService {
  SheetsApi? _api;

  Future<void> init() async {
    final jsonStr =
        await rootBundle.loadString('assets/service_account.json');
    final credentials =
        ServiceAccountCredentials.fromJson(jsonDecode(jsonStr) as Map);
    final client = await clientViaServiceAccount(
      credentials,
      [SheetsApi.spreadsheetsScope],
      baseClient: http.Client(),
    );
    _api = SheetsApi(client);
  }

  SheetsApi get _sheets {
    assert(_api != null, 'SheetsService not initialised — call init() first');
    return _api!;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<List<List<String>>> _getSheet(String sheet) async {
    final resp = await _sheets.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      '$sheet!A:Q',
    );
    final rows = resp.values ?? [];
    // skip header row (row 0)
    return rows.skip(1).map((r) => r.map((c) => c.toString()).toList()).toList();
  }

  String _s(List<String> row, int i) => i < row.length ? row[i] : '';
  double _d(List<String> row, int i) =>
      double.tryParse(_s(row, i).replaceAll(',', '.')) ?? 0;

  // Парсит учебный год из форматов "25/26" или "2025" → 2025
  int _parseAcademicYear(String s) {
    final slash = s.indexOf('/');
    if (slash != -1) {
      final start = s.substring(0, slash).trim();
      return start.length == 2
          ? 2000 + (int.tryParse(start) ?? 0)
          : int.tryParse(start) ?? 0;
    }
    return int.tryParse(s.trim()) ?? 0;
  }

  Future<int?> _findRowById(String sheet, String id) async {
    final resp = await _sheets.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      '$sheet!A:A',
    );
    final rows = resp.values ?? [];
    for (var i = 1; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == id) {
        return i + 1; // 1-based sheet row (row 1 is header)
      }
    }
    return null;
  }

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<List<AppUser>> getUsers() async {
    final rows = await _getSheet(AppConstants.sheetUsers);
    return rows
        .where((r) => r.isNotEmpty)
        .map((r) => AppUser(
              name: _s(r, 0),
              password: _s(r, 1),
              role: _s(r, 2) == 'admin' ? UserRole.admin : UserRole.teacher,
            ))
        .toList();
  }

  // ─── Assignments ──────────────────────────────────────────────────────────

  // Назначения: A=teacher, B=subject, C=group, D=year (формат "25/26" или "2025")
  Future<List<Assignment>> getAssignments(String teacherName, int year) async {
    final rows = await _getSheet(AppConstants.sheetAssign);
    return rows
        .where((r) =>
            r.isNotEmpty &&
            _s(r, 0) == teacherName &&
            _parseAcademicYear(_s(r, 3)) == year)
        .map((r) => Assignment(
              teacher: _s(r, 0),
              subject: _s(r, 1),
              group: _s(r, 2),
              year: _parseAcademicYear(_s(r, 3)),
            ))
        .toList();
  }

  // ─── Vychitki ─────────────────────────────────────────────────────────────

  Future<List<VychitkaEntry>> getVychitki({
    String? teacher,
    String? month,
    int? year,
  }) async {
    final rows = await _getSheet(AppConstants.sheetVychitki);
    return rows
        .where((r) {
          if (r.isEmpty) return false;
          if (teacher != null && _s(r, 1) != teacher) return false;
          if (month != null && _s(r, 2) != month) return false;
          if (year != null && _s(r, 3) != year.toString()) return false;
          return true;
        })
        // Вычитки: id(0) teacher(1) month(2) year(3) subject(4) group(5)
        //          лек(6) лр_пр(7) кп(8) конс(9) доп_контр(10) экз(11)
        //          status(12) submitted_at(13) confirmed_at(14) confirmed_by(15)
        .map((r) => VychitkaEntry(
              id: _s(r, 0),
              teacher: _s(r, 1),
              month: _s(r, 2),
              year: int.tryParse(_s(r, 3)) ?? 0,
              subject: _s(r, 4),
              group: _s(r, 5),
              lek: _d(r, 6),
              lrPr: _d(r, 7),
              kp: _d(r, 8),
              cons: _d(r, 9),
              dopKontr: _d(r, 10),
              ekz: _d(r, 11),
              status: _parseStatus(_s(r, 12)),
              submittedAt: _parseDate(_s(r, 13)),
              confirmedAt: _parseDate(_s(r, 14)),
              confirmedBy: _s(r, 15).isEmpty ? null : _s(r, 15),
            ))
        .toList();
  }

  VychitkaStatus _parseStatus(String s) {
    switch (s) {
      case 'submitted':
        return VychitkaStatus.submitted;
      case 'confirmed':
        return VychitkaStatus.confirmed;
      default:
        return VychitkaStatus.draft;
    }
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _statusStr(VychitkaStatus s) {
    switch (s) {
      case VychitkaStatus.submitted:
        return 'submitted';
      case VychitkaStatus.confirmed:
        return 'confirmed';
      case VychitkaStatus.draft:
        return 'draft';
    }
  }

  List<Object?> _entryToRow(VychitkaEntry e) => [
        e.id,
        e.teacher,
        e.month,
        e.year.toString(),
        e.subject,
        e.group,
        e.lek,
        e.lrPr,
        e.kp,
        e.cons,
        e.dopKontr,
        e.ekz,
        _statusStr(e.status),
        e.submittedAt?.toIso8601String() ?? '',
        e.confirmedAt?.toIso8601String() ?? '',
        e.confirmedBy ?? '',
      ];

  Future<void> saveEntries(List<VychitkaEntry> entries) async {
    if (entries.isEmpty) return;
    final body = ValueRange(
      values: entries.map(_entryToRow).toList(),
    );
    await _sheets.spreadsheets.values.append(
      body,
      AppConstants.spreadsheetId,
      '${AppConstants.sheetVychitki}!A:P',
      valueInputOption: 'RAW',
    );
  }

  Future<void> updateEntry(VychitkaEntry entry) async {
    final row = await _findRowById(AppConstants.sheetVychitki, entry.id);
    if (row == null) {
      await saveEntries([entry]);
      return;
    }
    final body = ValueRange(values: [_entryToRow(entry)]);
    await _sheets.spreadsheets.values.update(
      body,
      AppConstants.spreadsheetId,
      '${AppConstants.sheetVychitki}!A$row:P$row',
      valueInputOption: 'RAW',
    );
  }

  Future<void> _updateStatusForMonth(
    String teacher,
    String month,
    int year,
    VychitkaStatus status, {
    String? confirmedBy,
  }) async {
    final entries = await getVychitki(
      teacher: teacher,
      month: month,
      year: year,
    );
    final now = DateTime.now();
    for (final e in entries) {
      VychitkaEntry updated;
      switch (status) {
        case VychitkaStatus.submitted:
          updated = e.copyWith(status: status, submittedAt: now);
        case VychitkaStatus.confirmed:
          updated = e.copyWith(
            status: status,
            confirmedAt: now,
            confirmedBy: confirmedBy,
          );
        case VychitkaStatus.draft:
          updated = e.copyWith(status: status);
      }
      await updateEntry(updated);
    }
  }

  Future<void> submitMonth(String teacher, String month, int year) =>
      _updateStatusForMonth(teacher, month, year, VychitkaStatus.submitted);

  Future<void> confirmMonth(
    String teacher,
    String month,
    int year,
    String confirmedBy,
  ) =>
      _updateStatusForMonth(
        teacher,
        month,
        year,
        VychitkaStatus.confirmed,
        confirmedBy: confirmedBy,
      );

  Future<void> rejectMonth(String teacher, String month, int year) =>
      _updateStatusForMonth(teacher, month, year, VychitkaStatus.draft);

  // ─── Zameny ───────────────────────────────────────────────────────────────

  Future<List<Zamena>> getZameny(
      String teacher, String month, int year) async {
    final rows = await _getSheet(AppConstants.sheetZameny);
    return rows
        .where((r) =>
            r.isNotEmpty &&
            _s(r, 0) == teacher &&
            _s(r, 1) == month &&
            _s(r, 2) == year.toString())
        .map((r) => Zamena(
              teacher: _s(r, 0),
              month: _s(r, 1),
              year: int.tryParse(_s(r, 2)) ?? year,
              group: _s(r, 3),
              date: _s(r, 4),
              hours: _d(r, 5),
            ))
        .toList();
  }

  Future<void> saveZamena(Zamena z) async {
    final body = ValueRange(values: [
      [z.teacher, z.month, z.year.toString(), z.group, z.date, z.hours]
    ]);
    await _sheets.spreadsheets.values.append(
      body,
      AppConstants.spreadsheetId,
      '${AppConstants.sheetZameny}!A:F',
      valueInputOption: 'RAW',
    );
  }

  Future<void> deleteZamena(
      String teacher, String month, int year, String date) async {
    final resp = await _sheets.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      '${AppConstants.sheetZameny}!A:E',
    );
    final rows = resp.values ?? [];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i].map((c) => c.toString()).toList();
      if (_s(r, 0) == teacher &&
          _s(r, 1) == month &&
          _s(r, 2) == year.toString() &&
          _s(r, 4) == date) {
        final sheetRow = i + 1;
        // Clear the row
        await _sheets.spreadsheets.values.clear(
          ClearValuesRequest(),
          AppConstants.spreadsheetId,
          '${AppConstants.sheetZameny}!A$sheetRow:F$sheetRow',
        );
        return;
      }
    }
  }
}
