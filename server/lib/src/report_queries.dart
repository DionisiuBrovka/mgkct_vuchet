import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';

import 'auth_service.dart';
import 'api_error.dart';
import 'decimal.dart';
import 'pocketbase_store.dart';

const hourFields = {
  'lectureHours': 'lecture_hours',
  'practicalHours': 'practical_hours',
  'courseProjectHours': 'course_project_hours',
  'consultationHours': 'consultation_hours',
  'additionalAssessmentHours': 'additional_assessment_hours',
  'examHours': 'exam_hours',
};
const months = [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7];

class ReportQueries {
  ReportQueries(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final PocketBaseStore store;
  final DateTime Function() _clock;
  int currentAcademicYear() {
    final now = _clock().toUtc().add(const Duration(hours: 3));
    return now.month >= 9 ? now.year : now.year - 1;
  }

  void period(int year, int month) {
    if (year < 2000 || year > 2100 || !months.contains(month))
      throw const ApiError(422, 'Некорректный период', code: 'invalid_request');
  }

  int academicYear(int year, int month) => month >= 9 ? year : year - 1;
  void teacherOwn(Actor actor, String teacher, int year, int month) {
    period(year, month);
    if (actor.role != 'teacher' ||
        actor.id != teacher ||
        academicYear(year, month) != currentAcademicYear())
      throw const ApiError(
        403,
        'Период недоступен',
        code: 'teacher_period_unavailable',
      );
  }

  Future<Map<String, dynamic>> teacherPeriods(Actor actor) async {
    if (actor.role != 'teacher')
      throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
    final start = currentAcademicYear();
    final reports = await store.list(
      'teaching_reports',
      filter: 'teacher = {:teacher}',
      params: {'teacher': actor.id},
    );
    final status = {
      for (final row in reports)
        '${row.data['year']}-${row.data['month']}': row.data['status'],
    };
    return {
      'periods': [
        for (final month in months)
          {
            'academicYear': start,
            'year': month >= 9 ? start : start + 1,
            'month': month,
            'status':
                status['${month >= 9 ? start : start + 1}-$month'] ?? 'draft',
          },
      ],
    };
  }

  Future<List<RecordModel>> _annualHeaders(
    String teacher,
    int start,
  ) => store.list(
    'teaching_reports',
    filter:
        'teacher = {:teacher} && ((year = {:start} && month >= 9) || (year = {:end} && month <= 7))',
    params: {'teacher': teacher, 'start': start, 'end': start + 1},
  );

  String _versions(List<RecordModel> rows) {
    final versions = [
      for (final row in rows)
        '${row.id}:${row.data['revision']}:${row.data['status']}',
    ]..sort();
    return jsonEncode(versions);
  }

  Future<Map<String, dynamic>> _progress(
    String teacher,
    int start,
    String? currentId,
    List<RecordModel> headers,
  ) async {
    final assignments = await store.list(
      'assignments',
      filter: 'teacher = {:teacher} && academic_year = {:year}',
      params: {'teacher': teacher, 'year': start},
    );
    final zero = Decimal.parse('0');
    final result = <String, dynamic>{};
    for (final assignment in assignments) {
      Map<String, dynamic> category(String field) {
        final raw = assignment.data[field];
        return {
          'planned': raw == null || raw == ''
              ? null
              : Decimal.parse(raw).toString(),
          'confirmed': zero,
          'submitted': zero,
          'otherReported': zero,
        };
      }

      result[assignment.id] = {
        'main': category('planned_main_hours'),
        'additional': category('planned_additional_hours'),
      };
    }
    for (final header in headers) {
      final status = header.data['status'];
      if (status != 'confirmed' && status != 'submitted') continue;
      final rows = await store.list(
        'teaching_report_entries',
        filter: 'report = {:id}',
        params: {'id': header.id},
      );
      for (final row in rows) {
        final progress = result[row.data['assignment']];
        if (progress == null) continue;
        final additional = Decimal.parse(
          row.data['additional_assessment_hours'],
        );
        final main = sum(
          hourFields.values
              .where((key) => key != 'additional_assessment_hours')
              .map((key) => Decimal.parse(row.data[key])),
        );
        for (final item in {'main': main, 'additional': additional}.entries) {
          final category = progress[item.key] as Map<String, dynamic>;
          category[status] = (category[status] as Decimal) + item.value;
          // The editor adds its current form once, even for an already submitted report.
          if (header.id != currentId)
            category['otherReported'] =
                (category['otherReported'] as Decimal) + item.value;
        }
      }
    }
    for (final progress in result.values) {
      for (final category in (progress as Map).values) {
        final planned = category['planned'] == null
            ? null
            : Decimal.parse(category['planned']);
        final difference = planned == null
            ? null
            : planned - (category['confirmed'] as Decimal);
        category['remaining'] = difference == null
            ? null
            : (difference.coefficient.isNegative ? zero : difference)
                  .toString();
        category['excess'] = difference == null
            ? null
            : (difference.coefficient.isNegative ? zero - difference : zero)
                  .toString();
        for (final key in ['confirmed', 'submitted', 'otherReported']) {
          category[key] = category[key].toString();
        }
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> annualProgress(
    Actor actor,
    String teacher,
    int year,
  ) async {
    if (actor.role != 'admin') {
      throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      final headers = await _annualHeaders(teacher, year);
      final progress = await _progress(teacher, year, null, headers);
      if (_versions(headers) ==
          _versions(await _annualHeaders(teacher, year))) {
        return progress;
      }
    }
    throw const ApiError(
      409,
      'Отчёты изменились. Повторите выгрузку.',
      code: 'revision_conflict',
    );
  }

  Future<Map<String, dynamic>> report(
    Actor actor,
    String teacher,
    int year,
    int month,
  ) async {
    if (actor.role == 'teacher')
      teacherOwn(actor, teacher, year, month);
    else if (actor.role != 'admin')
      throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
    final owner = await store.get('users', teacher);
    for (var attempt = 0; attempt < 3; attempt++) {
      final reports = await store.list(
        'teaching_reports',
        filter: 'teacher = {:teacher} && year = {:year} && month = {:month}',
        params: {'teacher': teacher, 'year': year, 'month': month},
      );
      if (reports.length > 1)
        throw const ApiError(409, 'Конфликт отчёта', code: 'revision_conflict');
      final header = reports.isEmpty ? null : reports.single;
      if (actor.role == 'admin' &&
          header != null &&
          header.data['status'] == 'draft')
        throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
      final annualHeaders = await _annualHeaders(
        teacher,
        academicYear(year, month),
      );
      final progress = await _progress(
        teacher,
        academicYear(year, month),
        header?.id,
        annualHeaders,
      );
      final entries = <Map<String, dynamic>>[];
      final substitutions = <Map<String, dynamic>>[];
      if (header != null) {
        final rows = await store.list(
          'teaching_report_entries',
          filter: 'report = {:id}',
          params: {'id': header.id},
          expand: 'assignment.subject,assignment.group',
        );
        for (final row in rows) {
          final assignment = await store.get(
            'assignments',
            row.data['assignment'] as String,
          );
          final subject = await store.get(
            'subjects',
            assignment.data['subject'] as String,
          );
          final group = await store.get(
            'groups',
            assignment.data['group'] as String,
          );
          final data = <String, dynamic>{
            'id': row.id,
            'assignment': {
              'id': assignment.id,
              'subject': subject.data['name'],
              'group': group.data['name'],
              'progress': progress[assignment.id],
            },
          };
          final values = <Decimal>[];
          for (final field in hourFields.entries) {
            final value = Decimal.parse(row.data[field.value]);
            data[field.key] = value.toString();
            values.add(value);
          }
          data['totalHours'] = sum(values).toString();
          entries.add(data);
        }
        final rowsSub = await store.list(
          'substitutions',
          filter: 'report = {:id}',
          params: {'id': header.id},
        );
        for (final row in rowsSub) {
          substitutions.add({
            'id': row.id,
            'date': row.data['date'],
            'description': row.data['description'],
            'hours': Decimal.parse(row.data['hours']).toString(),
          });
        }
      } else if (actor.role == 'teacher') {
        final assignments = await store.list(
          'assignments',
          filter: 'teacher = {:teacher} && academic_year = {:year}',
          params: {'teacher': teacher, 'year': academicYear(year, month)},
          expand: 'subject,group',
        );
        for (final row in assignments) {
          final subject = await store.get(
            'subjects',
            row.data['subject'] as String,
          );
          final group = await store.get('groups', row.data['group'] as String);
          entries.add({
            'id': null,
            'assignment': {
              'id': row.id,
              'subject': subject.data['name'],
              'group': group.data['name'],
              'progress': progress[row.id],
            },
            for (final key in hourFields.keys) key: '0',
            'totalHours': '0',
          });
        }
      }
      final totals = {
        for (final field in hourFields.keys)
          field: sum(
            entries.map((row) => Decimal.parse(row[field])),
          ).toString(),
      };
      final assignmentTotal = sum(
        entries.map((row) => Decimal.parse(row['totalHours'])),
      );
      final substitutionTotal = sum(
        substitutions.map((row) => Decimal.parse(row['hours'])),
      );
      if (header == null) {
        final again = await store.list(
          'teaching_reports',
          filter: 'teacher = {:teacher} && year = {:year} && month = {:month}',
          params: {'teacher': teacher, 'year': year, 'month': month},
        );
        if (again.isNotEmpty) continue;
      }
      if (header != null) {
        final current = await store.get('teaching_reports', header.id);
        if (current.data['revision'] != header.data['revision']) continue;
      }
      if (_versions(annualHeaders) !=
          _versions(await _annualHeaders(teacher, academicYear(year, month))))
        continue;
      return {
        'id': header?.id,
        'teacher': {'id': teacher, 'name': owner.data['name']},
        'period': {
          'academicYear': academicYear(year, month),
          'year': year,
          'month': month,
        },
        'status': header?.data['status'] ?? 'draft',
        'revision': header?.data['revision'] ?? 0,
        'confirmation': null,
        'entries': entries,
        'substitutions': substitutions,
        'totals': {
          ...totals,
          'assignmentTotal': assignmentTotal.toString(),
          'substitutionTotal': substitutionTotal.toString(),
          'grandTotal': (assignmentTotal + substitutionTotal).toString(),
        },
      };
    }
    throw const ApiError(
      409,
      'Отчёт изменился. Обновите данные.',
      code: 'revision_conflict',
    );
  }

  Future<Map<String, dynamic>> adminOverview(
    Actor actor,
    int year,
    int month, {
    String? query,
    String? requestedStatus,
  }) async {
    if (actor.role != 'admin')
      throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
    period(year, month);
    if (query != null && (query.length > 200 || query.trim() != query))
      throw const ApiError(422, 'Некорректный фильтр', code: 'invalid_request');
    if (requestedStatus != null &&
        !const {'draft', 'submitted', 'confirmed'}.contains(requestedStatus))
      throw const ApiError(422, 'Некорректный статус', code: 'invalid_request');
    final users = await store.list(
      'users',
      filter: 'role = "teacher" && is_active = true',
    );
    final reports = await store.list(
      'teaching_reports',
      filter: 'year = {:year} && month = {:month}',
      params: {'year': year, 'month': month},
    );
    final states = {
      for (final row in reports)
        row.data['teacher'] as String: row.data['status'] as String,
    };
    final teachers =
        [
              for (final user in users)
                {
                  'id': user.id,
                  'name': user.data['name'],
                  'status': states[user.id] ?? 'draft',
                },
            ]
            .where(
              (row) =>
                  (query == null ||
                      (row['name'] as String).toLowerCase().contains(
                        query.toLowerCase(),
                      )) &&
                  (requestedStatus == null || row['status'] == requestedStatus),
            )
            .toList()
          ..sort(
            (a, b) => '${a['name']}\u0000${a['id']}'.compareTo(
              '${b['name']}\u0000${b['id']}',
            ),
          );
    return {'teachers': teachers};
  }

  Future<Map<String, dynamic>> adminPeriods(Actor actor) async {
    if (actor.role != 'admin')
      throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
    final current = currentAcademicYear();
    final reports = await store.list('teaching_reports');
    final values = <String>{
      for (final month in months)
        '${month >= 9 ? current : current + 1}-$month',
      for (final row in reports) '${row.data['year']}-${row.data['month']}',
    };
    final periods =
        [
          for (final key in values)
            () {
              final p = key.split('-');
              final year = int.parse(p[0]);
              final month = int.parse(p[1]);
              if (!months.contains(month)) return null;
              return {
                'academicYear': academicYear(year, month),
                'year': year,
                'month': month,
              };
            }(),
        ].whereType<Map<String, dynamic>>().toList()..sort(
          (a, b) => ('${a['year']}-${a['month']}').compareTo(
            '${b['year']}-${b['month']}',
          ),
        );
    return {'periods': periods};
  }
}
