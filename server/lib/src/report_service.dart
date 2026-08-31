import 'package:pocketbase/pocketbase.dart';
import 'api_error.dart';
import 'pocketbase_store.dart';

const months = [
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
];
const hourFields = {
  'lectureHours': 'lecture_hours',
  'practicalHours': 'practical_hours',
  'courseProjectHours': 'course_project_hours',
  'consultationHours': 'consultation_hours',
  'additionalAssessmentHours': 'additional_assessment_hours',
  'examHours': 'exam_hours',
};

class ReportService {
  ReportService(this.store);
  final PocketBaseStore store;

  int academicYear(String month, int year) =>
      months.indexOf(month) < 4 ? year : year - 1;
  void period(String month, int year) {
    if (!months.contains(month) || year < 2000 || year > 2100) {
      throw const ApiError(400, 'Некорректный период');
    }
  }

  void access(Map<String, dynamic> actor, String teacher) {
    if (actor['role'] != 'admin' && actor['profileId'] != teacher) {
      throw const ApiError(403, 'Нет доступа к этому преподавателю');
    }
  }

  void admin(Map<String, dynamic> actor) {
    if (actor['role'] != 'admin') {
      throw const ApiError(403, 'Доступ только для завуча');
    }
  }

  Future<RecordModel> teacherProfile(String id) async {
    try {
      final profile = await store.get('user_profiles', id);
      if (profile.data['role'] != 'teacher') {
        throw const ApiError(404, 'Преподаватель не найден');
      }
      return profile;
    } on ClientException catch (error) {
      if (error.statusCode == 404) {
        throw const ApiError(404, 'Преподаватель не найден');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> report(
    Map<String, dynamic> actor,
    String teacher,
    String month,
    int year, {
    int retry = 0,
  }) async {
    access(actor, teacher);
    period(month, year);
    final profile = await teacherProfile(teacher);
    final rows = await store.list(
      'teaching_reports',
      filter: 'teacher = {:teacher} && month = {:month} && year = {:year}',
      params: {'teacher': teacher, 'month': month, 'year': year},
    );
    final record = rows.isEmpty ? null : rows.single;
    final status = record?.data['status'] as String? ?? 'draft';
    final entries = <Map<String, dynamic>>[];
    final substitutions = <Map<String, dynamic>>[];
    if (record != null) {
      final children = await store.list(
        'teaching_report_entries',
        filter: 'report = {:id}',
        params: {'id': record.id},
        expand: 'assignment',
      );
      for (final entry in children) {
        final expansion = entry.data['expand'] as Map?;
        final assignment = expansion?['assignment'] as Map?;
        if (assignment == null) {
          throw const ApiError(409, 'Назначение отчёта недоступно');
        }
        entries.add({
          'id': entry.id,
          'assignmentId': entry.data['assignment'],
          'teacher': teacher,
          'subject': assignment['subject'],
          'group': assignment['group'],
          for (final field in hourFields.entries)
            field.key: entry.data[field.value] ?? 0,
        });
      }
      final childrenSubstitutions = await store.list(
        'substitutions',
        filter: 'report = {:id}',
        params: {'id': record.id},
      );
      for (final item in childrenSubstitutions) {
        substitutions.add({
          'id': item.id,
          'teacher': teacher,
          'month': month,
          'year': year,
          'group': item.data['group'],
          'date': item.data['date'],
          'hours': item.data['hours'],
        });
      }
    }
    if (status == 'draft') {
      final assignments = await store.list(
        'assignments',
        filter: 'teacher = {:teacher} && year = {:year}',
        params: {'teacher': teacher, 'year': academicYear(month, year)},
      );
      for (final assignment in assignments) {
        if (!entries.any((entry) => entry['assignmentId'] == assignment.id)) {
          entries.add({
            'id': '',
            'assignmentId': assignment.id,
            'teacher': teacher,
            'subject': assignment.data['subject'],
            'group': assignment.data['group'],
            for (final field in hourFields.keys) field: 0,
          });
        }
      }
    }
    entries.sort(
      (a, b) => '${a['subject']} ${a['group']}'.compareTo(
        '${b['subject']} ${b['group']}',
      ),
    );
    String? confirmedBy;
    final confirmedId = record?.data['confirmed_by'] as String? ?? '';
    if (confirmedId.isNotEmpty) {
      confirmedBy =
          (await store.get('user_profiles', confirmedId)).data['display_name']
              as String;
    }
    for (final entry in entries) {
      entry.addAll({
        'month': month,
        'year': year,
        'status': status,
        'submittedAt': record?.data['submitted_at'],
        'confirmedAt': record?.data['confirmed_at'],
        'confirmedBy': confirmedBy,
      });
    }
    if (record != null &&
        (await store.get('teaching_reports', record.id)).data['revision'] !=
            record.data['revision']) {
      if (retry < 2) {
        return report(actor, teacher, month, year, retry: retry + 1);
      }
      throw const ApiError(
        409,
        'Отчёт изменился во время загрузки. Повторите запрос',
      );
    }
    return {
      'id': record?.id ?? '',
      'teacher': teacher,
      'teacherName': profile.data['display_name'],
      'month': month,
      'year': year,
      'status': status,
      'revision': record?.data['revision'] ?? 0,
      'submittedAt': record?.data['submitted_at'] ?? '',
      'confirmedAt': record?.data['confirmed_at'] ?? '',
      'confirmedById': confirmedId,
      'confirmedBy': confirmedBy,
      'entries': entries,
      'substitutions': substitutions,
      'totals': {
        for (final field in hourFields.keys)
          field: entries.fold<num>(0, (sum, e) => sum + (e[field] as num)),
        'substitutionHours': substitutions.fold<num>(
          0,
          (sum, e) => sum + (e['hours'] as num),
        ),
      },
    };
  }

  Future<Map<String, dynamic>> statuses(
    Map<String, dynamic> actor,
    String teacher,
    int year,
  ) async {
    access(actor, teacher);
    if (year < 2000 || year > 2099) {
      throw const ApiError(400, 'Некорректный учебный год');
    }
    await teacherProfile(teacher);
    final rows = await store.list(
      'teaching_reports',
      filter: 'teacher = {:id} && year >= {:start} && year <= {:end}',
      params: {'id': teacher, 'start': year, 'end': year + 1},
    );
    return {
      for (final row in rows)
        if (months.contains(row.data['month']) &&
            academicYear(
                  row.data['month'] as String,
                  (row.data['year'] as num).toInt(),
                ) ==
                year)
          row.data['month'] as String: row.data['status'],
    };
  }

  Future<List<Map<String, dynamic>>> overview(
    Map<String, dynamic> actor,
    String month,
    int year,
  ) async {
    admin(actor);
    period(month, year);
    final teachers = await store.list(
      'user_profiles',
      filter: 'role = "teacher"',
    );
    final reports = await store.list(
      'teaching_reports',
      filter: 'month = {:month} && year = {:year}',
      params: {'month': month, 'year': year},
    );
    final statuses = {
      for (final r in reports) r.data['teacher']: r.data['status'],
    };
    return [
      for (final teacher in teachers)
        {
          'id': teacher.id,
          'name': teacher.data['display_name'],
          'status': statuses[teacher.id] ?? 'draft',
        },
    ]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is! List ||
        value.length > 500 ||
        value.any((item) => item is! Map<String, dynamic>)) {
      throw const ApiError(422, 'Некорректный список записей');
    }
    return value.cast<Map<String, dynamic>>();
  }

  num _hours(dynamic value) {
    if (value is! num || !value.isFinite || value < 0 || value > 999) {
      throw const ApiError(422, 'Часы должны быть числом от 0 до 999');
    }
    return value;
  }

  String _text(dynamic value) {
    if (value is! String || value.trim().isEmpty || value.length > 200) {
      throw const ApiError(422, 'Заполните группу');
    }
    return value.trim();
  }

  String _date(dynamic value, String month, int year) {
    if (value is! String || !RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(value)) {
      throw const ApiError(422, 'Дата должна иметь формат ДД.ММ.ГГГГ');
    }
    final parts = value.split('.').map(int.parse).toList();
    final date = DateTime(parts[2], parts[1], parts[0]);
    final number = (months.indexOf(month) + 8) % 12 + 1;
    if (date.day != parts[0] ||
        date.month != parts[1] ||
        parts[1] != number ||
        parts[2] != year) {
      throw const ApiError(
        422,
        'Дата должна существовать и относиться к выбранному месяцу',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> change(
    Map<String, dynamic> actor,
    String teacher,
    String month,
    int year,
    String action,
    Map<String, dynamic> input,
  ) async {
    if (!['save', 'submit', 'confirm', 'reject'].contains(action)) {
      throw const ApiError(404, 'Операция не найдена');
    }
    final current = await report(actor, teacher, month, year);
    final revision = input['revision'];
    if (revision is! int || revision < 0) {
      throw const ApiError(422, 'Не указана версия отчёта');
    }
    if (revision != current['revision']) {
      throw const ApiError(
        409,
        'Отчёт уже изменён. Обновите данные перед сохранением',
      );
    }
    final editing = action == 'save' || action == 'submit';
    if (editing) {
      if (actor['role'] != 'teacher' || actor['profileId'] != teacher) {
        throw const ApiError(403, 'Изменять часы может только преподаватель');
      }
      if (current['status'] != 'draft') {
        throw const ApiError(409, 'Отправленный отчёт нельзя редактировать');
      }
    } else {
      admin(actor);
      if (current['status'] != 'submitted') {
        throw const ApiError(409, 'Проверять можно только отправленный отчёт');
      }
    }
    final knownEntries = {
      for (final entry in _items(current['entries']))
        entry['assignmentId']: entry,
    };
    final incoming = _items(editing ? input['entries'] : current['entries']);
    if (incoming.length != knownEntries.length ||
        incoming.map((e) => e['assignmentId']).toSet().length !=
            incoming.length) {
      throw const ApiError(422, 'Состав назначений изменился. Обновите отчёт');
    }
    final entries = <Map<String, dynamic>>[];
    for (final entry in incoming) {
      final original = knownEntries[entry['assignmentId']];
      if (original == null) throw const ApiError(422, 'Постороннее назначение');
      entries.add({
        'id': original['id'],
        'assignment': entry['assignmentId'],
        for (final field in hourFields.entries)
          field.value: _hours(entry[field.key]),
      });
    }
    final knownSubstitutions = {
      for (final s in _items(current['substitutions'])) s['id']: s,
    };
    final substitutions = <Map<String, dynamic>>[];
    final used = <String>{};
    for (final item in _items(
      editing ? input['substitutions'] : current['substitutions'],
    )) {
      final id = item['id'];
      if (id is! String || !used.add(id)) {
        throw const ApiError(422, 'Повторяющаяся замена');
      }
      final isNew = id.startsWith('local:');
      if (!isNew && !knownSubstitutions.containsKey(id)) {
        throw const ApiError(422, 'Посторонняя замена');
      }
      substitutions.add({
        'id': isNew ? '' : id,
        'group': _text(item['group']),
        'date': _date(item['date'], month, year),
        'hours': _hours(item['hours']),
      });
    }
    if (action == 'submit' && entries.isEmpty && substitutions.isEmpty) {
      throw const ApiError(422, 'Пустой отчёт отправить нельзя');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final status = switch (action) {
      'submit' => 'submitted',
      'confirm' => 'confirmed',
      _ => 'draft',
    };
    await store.writeReport({
      'teacher': teacher,
      'month': month,
      'year': year,
      'expected_revision': revision,
      'status': status,
      'submitted_at': action == 'submit'
          ? now
          : action == 'reject'
          ? ''
          : current['submittedAt'],
      'confirmed_at': action == 'confirm' ? now : '',
      'confirmed_by': action == 'confirm' ? actor['profileId'] : '',
      'entries': entries,
      'substitutions': substitutions,
    });
    return report(actor, teacher, month, year);
  }
}
