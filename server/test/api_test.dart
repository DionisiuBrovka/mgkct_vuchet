import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:teaching_hours_server/server.dart';

void main() {
  late Directory temporary;
  late Process dataProcess;
  late HttpServer server;
  late PocketBase data;
  late PocketBaseStore store;
  late String teacherId, adminId, queryTeacherId, assignmentId;
  const password = 'TemporaryIntegration123!';
  const origin = 'http://browser.test';

  Future<http.Response> request(
    String method,
    String path, {
    String? cookie,
    Object? body,
    String? requestOrigin = origin,
  }) async {
    final message = http.Request(
      method,
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    if (body != null) message.headers['content-type'] = 'application/json';
    if (requestOrigin != null) message.headers['origin'] = requestOrigin;
    if (cookie != null) message.headers['cookie'] = cookie;
    if (body != null) message.body = jsonEncode(body);
    return http.Response.fromStream(await message.send());
  }

  String session(http.Response response) =>
      response.headers['set-cookie']!.split(';').first;

  setUpAll(() async {
    final root = Directory.current.parent.path;
    temporary = await Directory.systemTemp.createTemp('mgkct-auth-');
    final binary = '$root/data/pocketbase/pocketbase';
    final flags = [
      '--dir=${temporary.path}/data',
      '--migrationsDir=$root/data/pocketbase/pb_migrations',
      '--hooksDir=$root/data/pocketbase/pb_hooks',
      '--automigrate=false',
    ];
    final setup = await Process.run(binary, [
      'superuser',
      'upsert',
      'service@example.invalid',
      password,
      ...flags,
    ]);
    expect(setup.exitCode, 0, reason: '${setup.stdout}\n${setup.stderr}');
    final reserved = await ServerSocket.bind('127.0.0.1', 0);
    final port = reserved.port;
    await reserved.close();
    dataProcess = await Process.start(binary, [
      'serve',
      '--http=127.0.0.1:$port',
      ...flags,
    ]);
    dataProcess.stdout.drain<void>();
    dataProcess.stderr.drain<void>();
    data = PocketBase('http://127.0.0.1:$port', reuseHTTPClient: true);
    for (var tries = 0; ; tries++) {
      try {
        await data.health.check();
        break;
      } catch (_) {
        if (tries == 100) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    await data
        .collection('_superusers')
        .authWithPassword('service@example.invalid', password);
    Future<String> user(String email, String name, String role) async =>
        (await data
                .collection('users')
                .create(
                  body: {
                    'email': email,
                    'password': password,
                    'passwordConfirm': password,
                    'name': name,
                    'role': role,
                    'is_active': true,
                    'auth_version': 1,
                  },
                ))
            .id;
    teacherId = await user(
      'teacher@example.invalid',
      'Одинаковое ФИО',
      'teacher',
    );
    adminId = await user('admin@example.invalid', 'Одинаковое ФИО', 'admin');
    queryTeacherId = await user(
      'query@example.invalid',
      'Точный преподаватель',
      'teacher',
    );
    final subject = await data
        .collection('subjects')
        .create(body: {'name': 'Математика', 'normalized_name': 'математика'});
    final group = await data
        .collection('groups')
        .create(body: {'name': 'ПР-1', 'normalized_name': 'пр-1'});
    assignmentId =
        (await data
                .collection('assignments')
                .create(
                  body: {
                    'teacher': queryTeacherId,
                    'subject': subject.id,
                    'group': group.id,
                    'academic_year': 2026,
                  },
                ))
            .id;
    store = PocketBaseStore(data.baseURL, 'service@example.invalid', password);
    server = await shelf_io.serve(
      createHandler(store, allowedOrigins: {origin}),
      '127.0.0.1',
      0,
    );
  });

  tearDownAll(() async {
    await server.close(force: true);
    store.close();
    data.close();
    dataProcess.kill();
    await dataProcess.exitCode;
    await temporary.delete(recursive: true);
  });

  test(
    'directory, login, restore and logout expose no PB credentials',
    () async {
      final directory = await request(
        'GET',
        '/api/auth/users',
        requestOrigin: null,
      );
      expect(directory.statusCode, 200);
      expect(
        (jsonDecode(directory.body)['users'] as List).every(
          (row) =>
              (row as Map).keys.toSet().containsAll({'id', 'name'}) &&
              row.keys.length == 2,
        ),
        isTrue,
      );
      final missing = await request('GET', '/api/auth/me', requestOrigin: null);
      expect(missing.statusCode, 401);
      expect(missing.headers['set-cookie'], contains('Max-Age=0'));
      expect(
        (await request(
          'POST',
          '/api/auth/login',
          body: {'userId': teacherId, 'password': password},
          requestOrigin: null,
        )).statusCode,
        400,
      );
      final login = await request(
        'POST',
        '/api/auth/login',
        body: {'userId': teacherId, 'password': password},
      );
      expect(login.statusCode, 200, reason: login.body);
      expect(jsonDecode(login.body), {
        'user': {'id': teacherId, 'name': 'Одинаковое ФИО', 'role': 'teacher'},
      });
      expect(login.body, isNot(contains('token')));
      final credential = session(login);
      expect(credential, startsWith('mgkct_session='));
      expect(
        login.headers['set-cookie'],
        allOf(
          contains('HttpOnly'),
          contains('SameSite=Strict'),
          isNot(contains('Secure')),
        ),
      );
      final me = await request(
        'GET',
        '/api/auth/me',
        cookie: credential,
        requestOrigin: null,
      );
      expect(me.statusCode, 200);
      expect(jsonDecode(me.body)['user']['id'], teacherId);
      final logout = await request(
        'POST',
        '/api/auth/logout',
        cookie: credential,
        body: {},
      );
      expect(logout.statusCode, 204);
      expect(logout.headers['set-cookie'], contains('Max-Age=0'));
      expect(
        (await request(
          'GET',
          '/api/auth/me',
          cookie: credential,
          requestOrigin: null,
        )).statusCode,
        401,
      );
      expect(
        (await request('POST', '/api/auth/logout', body: {})).statusCode,
        204,
      );
    },
  );

  test(
    'active version and request context are rechecked on every request',
    () async {
      Future<String> login(String id) async => session(
        await request(
          'POST',
          '/api/auth/login',
          body: {'userId': id, 'password': password},
        ),
      );
      final teacher = await login(teacherId);
      final admin = await login(adminId);
      expect(
        jsonDecode(
          (await request(
            'GET',
            '/api/auth/me',
            cookie: teacher,
            requestOrigin: null,
          )).body,
        )['user']['role'],
        'teacher',
      );
      expect(
        jsonDecode(
          (await request(
            'GET',
            '/api/auth/me',
            cookie: admin,
            requestOrigin: null,
          )).body,
        )['user']['role'],
        'admin',
      );
      await data
          .collection('users')
          .update(
            teacherId,
            body: {'role': 'admin', 'is_active': true, 'auth_version': 2},
          );
      final revoked = await request(
        'GET',
        '/api/auth/me',
        cookie: teacher,
        requestOrigin: null,
      );
      expect(revoked.statusCode, 401);
      expect(revoked.headers['set-cookie'], contains('Max-Age=0'));
      final changed = await login(teacherId);
      expect(
        jsonDecode(
          (await request(
            'GET',
            '/api/auth/me',
            cookie: changed,
            requestOrigin: null,
          )).body,
        )['user']['role'],
        'admin',
      );
      await data
          .collection('users')
          .update(teacherId, body: {'is_active': false, 'auth_version': 3});
      expect(
        (await request(
          'GET',
          '/api/auth/me',
          cookie: changed,
          requestOrigin: null,
        )).statusCode,
        401,
      );
      expect(
        (await request(
          'POST',
          '/api/auth/login',
          body: {'userId': teacherId, 'password': password},
        )).statusCode,
        401,
      );
    },
  );

  test(
    'teacher and admin queries return exact separated totals and enforce scope',
    () async {
      Future<String> login(String id) async => session(
        await request(
          'POST',
          '/api/auth/login',
          body: {'userId': id, 'password': password},
        ),
      );
      final teacher = await login(queryTeacherId);
      final admin = await login(adminId);
      final periods = await request(
        'GET',
        '/api/teacher/periods',
        cookie: teacher,
        requestOrigin: null,
      );
      expect(periods.statusCode, 200);
      expect((jsonDecode(periods.body)['periods'] as List), hasLength(11));
      final initial = await request(
        'GET',
        '/api/reports/$queryTeacherId/2026/9',
        cookie: teacher,
        requestOrigin: null,
      );
      expect(initial.statusCode, 200);
      final empty = jsonDecode(initial.body) as Map<String, dynamic>;
      expect(empty['revision'], 0);
      expect(empty['entries'][0]['assignment']['id'], assignmentId);
      expect(empty['totals']['grandTotal'], '0');
      expect(
        (await request(
          'GET',
          '/api/reports/$teacherId/2026/9',
          cookie: teacher,
          requestOrigin: null,
        )).statusCode,
        403,
      );
      await data.send(
        '/api/internal/report-write',
        method: 'POST',
        body: {
          'teacher': queryTeacherId,
          'year': 2026,
          'month': 9,
          'status': 'submitted',
          'submitted_at': null,
          'confirmed_at': null,
          'confirmed_by': null,
          'expected_revision': 0,
          'entries': [
            {
              'id': null,
              'assignment': assignmentId,
              'lecture_hours': '0.1',
              'practical_hours': '0.2',
              'course_project_hours':
                  '0.123456789012345678901234567890123456789',
              'consultation_hours': '0',
              'additional_assessment_hours': '0',
              'exam_hours': '0',
            },
          ],
          'substitutions': [
            {
              'id': null,
              'date': '2026-09-05',
              'description': 'Замена',
              'hours': '0.000000000000000000000000000000000001',
            },
          ],
        },
      );
      final response = await request(
        'GET',
        '/api/reports/$queryTeacherId/2026/9',
        cookie: teacher,
        requestOrigin: null,
      );
      expect(response.statusCode, 200, reason: response.body);
      final value = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
        value['totals']['assignmentTotal'],
        '0.423456789012345678901234567890123456789',
      );
      expect(
        value['totals']['substitutionTotal'],
        '0.000000000000000000000000000000000001',
      );
      expect(
        value['totals']['grandTotal'],
        '0.423456789012345678901234567890123457789',
      );
      final overview = await request(
        'GET',
        '/api/admin/reports?year=2026&month=9&status=submitted',
        cookie: admin,
        requestOrigin: null,
      );
      expect(overview.statusCode, 200);
      expect(
        (jsonDecode(overview.body)['teachers'] as List).single['id'],
        queryTeacherId,
      );
    },
  );

  test(
    'all-month overview uses academic years, filters and admin scope',
    () async {
      final user = await data
          .collection('users')
          .create(
            body: {
              'email': 'annual-overview@example.invalid',
              'password': password,
              'passwordConfirm': password,
              'name': 'Годовой обзор',
              'role': 'teacher',
              'is_active': true,
              'auth_version': 1,
            },
          );
      for (final p in [(2025, 9), (2026, 9), (2027, 1), (2027, 9)]) {
        await data.send(
          '/api/internal/report-write',
          method: 'POST',
          body: {
            'teacher': user.id,
            'year': p.$1,
            'month': p.$2,
            'status': p.$2 == 1 ? 'draft' : 'submitted',
            'submitted_at': null,
            'confirmed_at': null,
            'confirmed_by': null,
            'expected_revision': 0,
            'entries': [],
            'substitutions': [
              {
                'id': null,
                'date': '${p.$1}-${p.$2.toString().padLeft(2, '0')}-05',
                'description': 'Замена',
                'hours': '1',
              },
            ],
          },
        );
      }
      final admin = session(
        await request(
          'POST',
          '/api/auth/login',
          body: {'userId': adminId, 'password': password},
        ),
      );
      final teacher = session(
        await request(
          'POST',
          '/api/auth/login',
          body: {'userId': user.id, 'password': password},
        ),
      );
      final path =
          '/api/admin/reports?academicYear=2026&q=${Uri.encodeQueryComponent('Годовой')}';
      final all = await request('GET', path, cookie: admin);
      expect(all.statusCode, 200, reason: all.body);
      final rows = jsonDecode(all.body)['teachers'] as List;
      expect(rows.map((r) => [r['year'], r['month']]).toList(), [
        [2027, 1],
        [2026, 9],
      ]);
      expect(rows.every((r) => r['id'] == user.id), isTrue);
      final filtered = await request(
        'GET',
        '$path&status=submitted',
        cookie: admin,
      );
      expect(
        (jsonDecode(filtered.body)['teachers'] as List).single['month'],
        9,
      );
      final empty = await request(
        'GET',
        '$path&status=confirmed',
        cookie: admin,
      );
      expect(jsonDecode(empty.body)['teachers'], isEmpty);
      expect((await request('GET', path, cookie: teacher)).statusCode, 403);
      for (final query in [
        'academicYear=bad',
        'academicYear=2026&month=9',
        'academicYear=2026&year=2026',
        'year=2026',
        'academicYear=2100',
      ]) {
        expect(
          (await request(
            'GET',
            '/api/admin/reports?$query',
            cookie: admin,
          )).statusCode,
          422,
        );
      }
    },
  );

  test('save, submit, return and confirm use one revision each', () async {
    Future<String> login(String id) async => session(
      await request(
        'POST',
        '/api/auth/login',
        body: {'userId': id, 'password': password},
      ),
    );
    final teacher = await login(queryTeacherId);
    final admin = await login(adminId);
    final body = {
      'revision': 0,
      'entries': [
        {
          'id': null,
          'assignmentId': assignmentId,
          'lectureHours': '1',
          'practicalHours': '0',
          'courseProjectHours': '0',
          'consultationHours': '0',
          'additionalAssessmentHours': '0',
          'examHours': '0',
        },
      ],
      'substitutions': [],
    };
    final saved = await request(
      'PUT',
      '/api/teacher/reports/2026/10',
      cookie: teacher,
      body: body,
    );
    expect(saved.statusCode, 200, reason: saved.body);
    final one = jsonDecode(saved.body) as Map<String, dynamic>;
    expect(
      (await request(
        'PUT',
        '/api/teacher/reports/2026/10',
        cookie: teacher,
        body: body,
      )).statusCode,
      409,
    );
    final entry = (one['entries'] as List).single as Map<String, dynamic>;
    final next = {
      ...body,
      'revision': one['revision'],
      'entries': [
        {
          'id': entry['id'],
          'assignmentId': assignmentId,
          'lectureHours': '1',
          'practicalHours': '0',
          'courseProjectHours': '0',
          'consultationHours': '0',
          'additionalAssessmentHours': '0',
          'examHours': '0',
        },
      ],
    };
    final submitted = await request(
      'POST',
      '/api/teacher/reports/2026/10/submit',
      cookie: teacher,
      body: next,
    );
    expect(submitted.statusCode, 200, reason: submitted.body);
    final two = jsonDecode(submitted.body) as Map<String, dynamic>;
    final returned = await request(
      'POST',
      '/api/admin/reports/$queryTeacherId/2026/10/return',
      cookie: admin,
      body: {'revision': two['revision']},
    );
    expect(returned.statusCode, 200, reason: returned.body);
  });
  test(
    'annual plans separate statuses, categories and years without blocking excess',
    () async {
      final user = await data
          .collection('users')
          .create(
            body: {
              'email': 'plan@example.invalid',
              'password': password,
              'passwordConfirm': password,
              'name': 'Годовой план',
              'role': 'teacher',
              'is_active': true,
              'auth_version': 1,
            },
          );
      final source = await data.collection('assignments').getOne(assignmentId);
      final assignment = await data
          .collection('assignments')
          .create(
            body: {
              'teacher': user.id,
              'subject': source.data['subject'],
              'group': source.data['group'],
              'academic_year': 2026,
              'planned_main_hours': '0.25',
              'planned_additional_hours': '0.1',
            },
          );
      for (final invalid in ['-1', '1.00', '1,5', 'abc']) {
        await expectLater(
          data
              .collection('assignments')
              .update(assignment.id, body: {'planned_main_hours': invalid}),
          throwsA(isA<ClientException>()),
        );
      }
      Future<String> login(String id) async => session(
        await request(
          'POST',
          '/api/auth/login',
          body: {'userId': id, 'password': password},
        ),
      );
      final teacher = await login(user.id);
      final admin = await login(adminId);
      Future<Map<String, dynamic>> write(
        int year,
        int month,
        String main,
        String additional, {
        bool submit = true,
        int revision = 0,
        String? entryId,
      }) async {
        final response = await request(
          submit ? 'POST' : 'PUT',
          '/api/teacher/reports/$year/$month${submit ? '/submit' : ''}',
          cookie: teacher,
          body: {
            'revision': revision,
            'entries': [
              {
                'id': entryId,
                'assignmentId': assignment.id,
                'lectureHours': main,
                'practicalHours': '0',
                'courseProjectHours': '0',
                'consultationHours': '0',
                'additionalAssessmentHours': additional,
                'examHours': '0',
              },
            ],
            'substitutions': [
              {
                'id': null,
                'date': '$year-${month.toString().padLeft(2, '0')}-01',
                'description': 'Замена вне плана',
                'hours': '5',
              },
            ],
          },
        );
        expect(response.statusCode, 200, reason: response.body);
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      Future<Map<String, dynamic>> transition(
        int year,
        int month,
        String action,
        int revision,
      ) async {
        final response = await request(
          'POST',
          '/api/admin/reports/${user.id}/$year/$month/$action',
          cookie: admin,
          body: {'revision': revision},
        );
        expect(response.statusCode, 200, reason: response.body);
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      Map<String, dynamic> progress(Map<String, dynamic> report) =>
          report['entries'][0]['assignment']['progress']
              as Map<String, dynamic>;
      final oldAssignment = await data
          .collection('assignments')
          .create(
            body: {
              'teacher': user.id,
              'subject': source.data['subject'],
              'group': source.data['group'],
              'academic_year': 2025,
            },
          );
      final oldReport = await data
          .collection('teaching_reports')
          .create(
            body: {
              'teacher': user.id,
              'year': 2025,
              'month': 9,
              'status': 'confirmed',
              'revision': 1,
            },
          );
      await data
          .collection('teaching_report_entries')
          .create(
            body: {
              'report': oldReport.id,
              'assignment': oldAssignment.id,
              'lecture_hours': '77',
              'practical_hours': '0',
              'course_project_hours': '0',
              'consultation_hours': '0',
              'additional_assessment_hours': '0',
              'exam_hours': '0',
            },
          );
      final september = await write(2026, 9, '0.1', '0.05');
      await transition(2026, 9, 'confirm', september['revision'] as int);
      await write(2026, 10, '9', '9', submit: false);
      final january = await write(2027, 1, '0.2', '0.07');
      final p = progress(january);
      expect(p['main'], {
        'planned': '0.25',
        'confirmed': '0.1',
        'submitted': '0.2',
        'otherReported': '0.1',
        'remaining': '0.15',
        'excess': '0',
      });
      expect(p['additional'], {
        'planned': '0.1',
        'confirmed': '0.05',
        'submitted': '0.07',
        'otherReported': '0.05',
        'remaining': '0.05',
        'excess': '0',
      });
      final review = await request(
        'GET',
        '/api/reports/${user.id}/2027/1',
        cookie: admin,
      );
      expect(review.statusCode, 200);
      expect(progress(jsonDecode(review.body)), p);
      final returned = await transition(
        2027,
        1,
        'return',
        january['revision'] as int,
      );
      expect(progress(returned)['main']['submitted'], '0');
      final resubmitted = await write(
        2027,
        1,
        '0.2',
        '0.07',
        revision: returned['revision'] as int,
        entryId: returned['entries'][0]['id'] as String,
      );
      final confirmed = await transition(
        2027,
        1,
        'confirm',
        resubmitted['revision'] as int,
      );
      expect(progress(confirmed)['main']['confirmed'], '0.3');
      expect(progress(confirmed)['main']['submitted'], '0');
      expect(progress(confirmed)['main']['remaining'], '0');
      expect(progress(confirmed)['main']['excess'], '0.05');
      expect(progress(confirmed)['additional']['confirmed'], '0.12');
      expect(progress(confirmed)['additional']['excess'], '0.02');
      final empty = await request(
        'GET',
        '/api/reports/${user.id}/2026/11',
        cookie: teacher,
      );
      expect(progress(jsonDecode(empty.body))['main']['otherReported'], '0.3');
      final otherYear = await request(
        'GET',
        '/api/reports/${user.id}/2025/9',
        cookie: admin,
      );
      expect(progress(jsonDecode(otherYear.body))['main']['confirmed'], '77');
      expect(progress(jsonDecode(otherYear.body))['main']['planned'], isNull);
      final forbidden = await request(
        'GET',
        '/api/reports/$queryTeacherId/2026/9',
        cookie: teacher,
      );
      expect(forbidden.statusCode, 403);
    },
  );
  test(
    'statistics are admin only, filtered by identity and exported as xlsx',
    () async {
      Future<String> login(String id) async => session(
        await request(
          'POST',
          '/api/auth/login',
          body: {'userId': id, 'password': password},
        ),
      );
      final teacher = await login(queryTeacherId);
      final admin = await login(adminId);
      for (final path in [
        '/api/admin/statistics',
        '/api/admin/statistics/options',
        '/api/admin/statistics.xlsx',
      ]) {
        expect((await request('GET', path)).statusCode, 401);
        expect((await request('GET', path, cookie: teacher)).statusCode, 403);
      }
      final optionsResponse = await request(
        'GET',
        '/api/admin/statistics/options',
        cookie: admin,
      );
      expect(optionsResponse.statusCode, 200);
      final options = jsonDecode(optionsResponse.body) as Map;
      expect(options['years'], containsAll([2025, 2026]));
      final planTeacher = (options['teachers'] as List).singleWhere(
        (row) => row['name'] == 'Годовой план',
      )['id'];
      final source = await data.collection('assignments').getOne(assignmentId);
      final filter =
          'academicYear=2026&teacher=$planTeacher&subject=${source.data['subject']}&group=${source.data['group']}';
      final response = await request(
        'GET',
        '/api/admin/statistics?$filter',
        cookie: admin,
      );
      expect(response.statusCode, 200, reason: response.body);
      final statistics = jsonDecode(response.body) as Map;
      expect(statistics['rows'], hasLength(1));
      expect(statistics['totals']['main']['confirmed'], '0.3');
      expect(statistics['totals']['main']['planned'], '0.25');
      expect(statistics['totals']['main']['excess'], '0.05');
      expect(statistics['totals']['additional']['confirmed'], '0.12');
      final allYears = await request(
        'GET',
        '/api/admin/statistics?teacher=$planTeacher',
        cookie: admin,
      );
      expect(jsonDecode(allYears.body)['rows'], hasLength(2));
      expect(jsonDecode(allYears.body)['totals']['main']['missingPlans'], 1);
      for (final filter in [
        'academicYear=abc',
        'academicYear=1999',
        'teacher=invalid',
        'unknown=x',
      ]) {
        expect(
          (await request(
            'GET',
            '/api/admin/statistics?$filter',
            cookie: admin,
          )).statusCode,
          422,
        );
      }
      final empty = await request(
        'GET',
        '/api/admin/statistics?academicYear=2040',
        cookie: admin,
      );
      expect(jsonDecode(empty.body)['rows'], isEmpty);
      final excel = await request(
        'GET',
        '/api/admin/statistics.xlsx?$filter',
        cookie: admin,
      );
      expect(excel.statusCode, 200);
      expect(excel.headers['content-type'], contains('spreadsheetml.sheet'));
      expect(excel.headers['content-disposition'], contains('attachment'));
      expect(excel.bodyBytes.take(2), [80, 75]);
    },
  );
}
