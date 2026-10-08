import 'api_error.dart';
import 'auth_service.dart';
import 'decimal.dart';
import 'pocketbase_store.dart';
import 'report_queries.dart';

class StatisticsService {
  StatisticsService(this.store, this.queries);
  final PocketBaseStore store;
  final ReportQueries queries;

  void _admin(Actor actor) {
    if (actor.role != 'admin') {
      throw const ApiError(403, 'Доступ запрещён', code: 'forbidden');
    }
  }

  Future<Map<String, dynamic>> options(Actor actor) async {
    _admin(actor);
    final assignments = await store.list('assignments');
    Future<List<Map<String, dynamic>>> names(
      String collection,
      String field,
    ) async {
      final ids = assignments.map((row) => row.data[field]).toSet();
      final rows = await store.list(collection);
      return [
        for (final row in rows)
          if (ids.contains(row.id)) {'id': row.id, 'name': row.data['name']},
      ]..sort(
        (a, b) => '${a['name']}${a['id']}'.compareTo('${b['name']}${b['id']}'),
      );
    }

    return {
      'years': {
        queries.currentAcademicYear(),
        ...assignments.map((row) => row.data['academic_year'] as int),
      }.toList()..sort((a, b) => b.compareTo(a)),
      'teachers': await names('users', 'teacher'),
      'subjects': await names('subjects', 'subject'),
      'groups': await names('groups', 'group'),
    };
  }

  Future<Map<String, dynamic>> read(
    Actor actor,
    Map<String, String> filters,
  ) async {
    _admin(actor);
    if (filters.keys.any(
      (key) => !{'academicYear', 'teacher', 'subject', 'group'}.contains(key),
    )) {
      throw const ApiError(422, 'Неизвестный фильтр', code: 'invalid_request');
    }
    final year = filters['academicYear'] == null
        ? null
        : int.tryParse(filters['academicYear']!);
    if (filters.containsKey('academicYear') &&
        (year == null || year < 2000 || year > 2100)) {
      throw const ApiError(
        422,
        'Укажите корректный учебный год',
        code: 'invalid_request',
      );
    }
    for (final field in ['teacher', 'subject', 'group']) {
      if (filters[field] != null &&
          !RegExp(r'^[a-z0-9]{15}$').hasMatch(filters[field]!)) {
        throw const ApiError(
          422,
          'Некорректный фильтр',
          code: 'invalid_request',
        );
      }
    }
    final assignments = await store.list(
      'assignments',
      filter: [
        if (year != null) 'academic_year = {:academicYear}',
        for (final field in ['teacher', 'subject', 'group'])
          if (filters[field] != null) '$field = {:$field}',
      ].join(' && '),
      params: {...filters, if (year != null) 'academicYear': year},
    );
    final users = {
      for (final row in await store.list('users')) row.id: row.data['name'],
    };
    final subjects = {
      for (final row in await store.list('subjects')) row.id: row.data['name'],
    };
    final groups = {
      for (final row in await store.list('groups')) row.id: row.data['name'],
    };
    final progress = <String, Map<String, dynamic>>{};
    final rows = <Map<String, dynamic>>[];
    for (final assignment in assignments) {
      final teacher = assignment.data['teacher'] as String;
      final academicYear = assignment.data['academic_year'] as int;
      final key = '$teacher:$academicYear';
      progress[key] ??= await queries.annualProgress(
        actor,
        teacher,
        academicYear,
      );
      rows.add({
        'id': assignment.id,
        'academicYear': academicYear,
        'teacher': users[teacher],
        'subject': subjects[assignment.data['subject']],
        'group': groups[assignment.data['group']],
        'progress': progress[key]![assignment.id],
      });
    }
    rows.sort(
      (a, b) => '${b['academicYear']}'.compareTo('${a['academicYear']}') != 0
          ? '${b['academicYear']}'.compareTo('${a['academicYear']}')
          : '${a['teacher']}\u0000${a['subject']}\u0000${a['group']}\u0000${a['id']}'
                .compareTo(
                  '${b['teacher']}\u0000${b['subject']}\u0000${b['group']}\u0000${b['id']}',
                ),
    );
    final totals = <String, dynamic>{};
    for (final category in ['main', 'additional']) {
      final values = [
        for (final row in rows) (row['progress'] as Map)[category] as Map,
      ];
      totals[category] = {
        for (final field in [
          'planned',
          'confirmed',
          'submitted',
          'remaining',
          'excess',
        ])
          field: sum(
            values
                .where((value) => value[field] != null)
                .map((value) => Decimal.parse(value[field])),
          ).toString(),
        'missingPlans': values
            .where((value) => value['planned'] == null)
            .length,
      };
    }
    return {
      'rows': rows,
      'totals': totals,
      'filters': filters,
      'filterLabels': {
        if (year != null) 'Учебный год': '$year–${year + 1}',
        if (filters['teacher'] != null)
          'Преподаватель': users[filters['teacher']] ?? 'Не найден',
        if (filters['subject'] != null)
          'Предмет': subjects[filters['subject']] ?? 'Не найден',
        if (filters['group'] != null)
          'Группа': groups[filters['group']] ?? 'Не найдена',
      },
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
