import 'auth_service.dart';
import 'api_error.dart';
import 'decimal.dart';
import 'pocketbase_store.dart';
import 'report_queries.dart';

class ReportCommands {
  ReportCommands(this.store, this.queries, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final PocketBaseStore store;
  final ReportQueries queries;
  final DateTime Function() _clock;
  static const fields = [
    'lectureHours',
    'practicalHours',
    'courseProjectHours',
    'consultationHours',
    'additionalAssessmentHours',
    'examHours',
  ];
  static const storage = {
    'lectureHours': 'lecture_hours',
    'practicalHours': 'practical_hours',
    'courseProjectHours': 'course_project_hours',
    'consultationHours': 'consultation_hours',
    'additionalAssessmentHours': 'additional_assessment_hours',
    'examHours': 'exam_hours',
  };
  void exact(Map<String, dynamic> value, Set<String> keys) {
    if (value.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(value.containsKey))
      throw const ApiError(422, 'Некорректный запрос', code: 'invalid_request');
  }

  String text(dynamic value, int max) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.trim() != value ||
        value.length > max)
      throw const ApiError(422, 'Некорректный текст', code: 'invalid_request');
    return value;
  }

  String date(dynamic value, int year, int month) {
    final raw = text(value, 10);
    final parsed = DateTime.tryParse(raw);
    if (parsed == null ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.toIso8601String().substring(0, 10) != raw)
      throw const ApiError(
        422,
        'Некорректная дата замены',
        code: 'invalid_date',
      );
    return raw;
  }

  Future<Map<String, dynamic>> save(
    Actor actor,
    int year,
    int month,
    Map<String, dynamic> body, {
    required bool submit,
  }) async {
    queries.teacherOwn(actor, actor.id, year, month);
    exact(body, {'revision', 'entries', 'substitutions'});
    if (body['revision'] is! int ||
        (body['revision'] as int) < 0 ||
        body['entries'] is! List ||
        body['substitutions'] is! List)
      throw const ApiError(422, 'Некорректный запрос', code: 'invalid_request');
    final expected = body['revision'] as int;
    final entries = <Map<String, dynamic>>[];
    final ids = <String>{};
    final assignments = <String>{};
    for (final item in body['entries'] as List) {
      if (item is! Map<String, dynamic>)
        throw const ApiError(
          422,
          'Некорректная строка',
          code: 'invalid_request',
        );
      exact(item, {'id', 'assignmentId', ...fields});
      final id = item['id'];
      if (id != null && (id is! String || !ids.add(id)))
        throw const ApiError(
          422,
          'Некорректный ID строки',
          code: 'invalid_request',
        );
      final assignment = text(item['assignmentId'], 15);
      if (!assignments.add(assignment))
        throw const ApiError(422, 'Повтор назначения', code: 'invalid_request');
      final record = await store.get('assignments', assignment);
      if (record.data['teacher'] != actor.id ||
          record.data['academic_year'] != queries.academicYear(year, month))
        throw const ApiError(
          409,
          'Состав назначений изменился',
          code: 'assignment_set_changed',
        );
      entries.add({
        'id': id,
        'assignment': assignment,
        for (final field in fields)
          storage[field]!: Decimal.parse(item[field]).toString(),
      });
    }
    final current = await store.list(
      'assignments',
      filter: 'teacher = {:teacher} && academic_year = {:year}',
      params: {'teacher': actor.id, 'year': queries.academicYear(year, month)},
    );
    if (!assignments.containsAll(current.map((r) => r.id)) ||
        assignments.length != current.length)
      throw const ApiError(
        409,
        'Состав назначений изменился',
        code: 'assignment_set_changed',
      );
    final substitutions = <Map<String, dynamic>>[];
    final subIds = <String>{};
    for (final item in body['substitutions'] as List) {
      if (item is! Map<String, dynamic>)
        throw const ApiError(
          422,
          'Некорректная замена',
          code: 'invalid_request',
        );
      exact(item, {'id', 'date', 'description', 'hours'});
      final id = item['id'];
      if (id != null && (id is! String || !subIds.add(id)))
        throw const ApiError(
          422,
          'Некорректный ID замены',
          code: 'invalid_request',
        );
      substitutions.add({
        'id': id,
        'date': date(item['date'], year, month),
        'description': text(item['description'], 500),
        'hours': Decimal.parse(item['hours']).toString(),
      });
    }
    final total = sum([
      ...entries.expand((e) => fields.map((f) => Decimal.parse(e[storage[f]]))),
      ...substitutions.map((s) => Decimal.parse(s['hours'])),
    ]);
    if (submit && total.coefficient == BigInt.zero)
      throw const ApiError(
        422,
        'Пустой отчёт нельзя отправить',
        code: 'empty_report',
      );
    final existing = await store.list(
      'teaching_reports',
      filter: 'teacher = {:teacher} && year = {:year} && month = {:month}',
      params: {'teacher': actor.id, 'year': year, 'month': month},
    );
    if (existing.length == 1 && existing.single.data['status'] != 'draft')
      throw const ApiError(
        409,
        'Статус отчёта изменился',
        code: 'status_conflict',
      );
    await store.writeReport({
      'teacher': actor.id,
      'year': year,
      'month': month,
      'status': submit ? 'submitted' : 'draft',
      'submitted_at': submit ? _clock().toUtc().toIso8601String() : null,
      'confirmed_at': null,
      'confirmed_by': null,
      'expected_revision': expected,
      'entries': entries,
      'substitutions': substitutions,
    });
    return queries.report(actor, actor.id, year, month);
  }

  Future<Map<String, dynamic>> transition(
    Actor actor,
    String teacher,
    int year,
    int month,
    int revision, {
    required bool confirm,
  }) async {
    if (actor.role != 'admin')
      throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
    final rows = await store.list(
      'teaching_reports',
      filter: 'teacher = {:teacher} && year = {:year} && month = {:month}',
      params: {'teacher': teacher, 'year': year, 'month': month},
    );
    if (rows.length != 1 || rows.single.data['status'] != 'submitted')
      throw const ApiError(
        409,
        'Статус отчёта изменился',
        code: 'status_conflict',
      );
    final r = rows.single;
    final entries = await store.list(
      'teaching_report_entries',
      filter: 'report = {:id}',
      params: {'id': r.id},
    );
    final subs = await store.list(
      'substitutions',
      filter: 'report = {:id}',
      params: {'id': r.id},
    );
    await store.writeReport({
      'teacher': teacher,
      'year': year,
      'month': month,
      'status': confirm ? 'confirmed' : 'draft',
      'submitted_at': r.data['submitted_at'],
      'confirmed_at': confirm ? _clock().toUtc().toIso8601String() : null,
      'confirmed_by': confirm ? actor.id : null,
      'expected_revision': revision,
      'entries': [
        for (final e in entries)
          {
            'id': e.id,
            'assignment': e.data['assignment'],
            for (final f in storage.values) f: e.data[f],
          },
      ],
      'substitutions': [
        for (final s in subs)
          {
            'id': s.id,
            'date': s.data['date'],
            'description': s.data['description'],
            'hours': s.data['hours'],
          },
      ],
    });
    return queries.report(
      confirm ? actor : Actor(teacher, '', 'teacher'),
      teacher,
      year,
      month,
    );
  }
}
