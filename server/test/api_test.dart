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
  late String teacherId, otherId, adminId, teacherToken, otherToken, adminToken;
  const password = 'TemporaryIntegration123!';
  String path(String month, [int year = 2026]) =>
      '/api/reports/$teacherId/$year/${Uri.encodeComponent(month)}';
  Future<http.Response> request(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final request =
        http.Request(method, Uri.parse('http://127.0.0.1:${server.port}$path'))
          ..headers.addAll({
            'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
          });
    if (body != null) request.body = jsonEncode(body);
    return http.Response.fromStream(await request.send());
  }

  Future<Map<String, dynamic>> load(String month, [int year = 2026]) async {
    final result = await request('GET', path(month, year), token: teacherToken);
    expect(result.statusCode, 200, reason: result.body);
    return jsonDecode(result.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> change(
    String month,
    String action,
    Map<String, dynamic> input, {
    String? token,
    int year = 2026,
  }) async {
    final result = await request(
      'POST',
      '${path(month, year)}/$action',
      token: token ?? teacherToken,
      body: input,
    );
    expect(result.statusCode, 200, reason: result.body);
    return jsonDecode(result.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> substitution(String id, String date) => {
    'id': 'local:$id',
    'date': date,
    'group': 'ПР-22',
    'hours': 2,
  };

  setUpAll(() async {
    final root = Directory.current.parent.path;
    temporary = await Directory.systemTemp.createTemp('teaching-hours-api-');
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
      'service@example.com',
      password,
      ...flags,
    ]);
    expect(setup.exitCode, 0, reason: '${setup.stdout}\n${setup.stderr}');
    final socket = await ServerSocket.bind('127.0.0.1', 0);
    final port = socket.port;
    await socket.close();
    dataProcess = await Process.start(binary, [
      'serve',
      '--http=127.0.0.1:$port',
      ...flags,
    ]);
    dataProcess.stdout.drain<void>();
    dataProcess.stderr.drain<void>();
    data = PocketBase('http://127.0.0.1:$port', reuseHTTPClient: true);
    for (var i = 0; ; i++) {
      try {
        await data.health.check();
        break;
      } catch (_) {
        if (i > 100) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    await data
        .collection('_superusers')
        .authWithPassword('service@example.com', password);
    Future<String> profile(String email, String name, String role) async {
      final account = await data
          .collection('users')
          .create(
            body: {
              'email': email,
              'password': password,
              'passwordConfirm': password,
            },
          );
      return (await data
              .collection('user_profiles')
              .create(
                body: {
                  'user': account.id,
                  'email': email,
                  'display_name': name,
                  'role': role,
                },
              ))
          .id;
    }

    teacherId = await profile(
      'teacher@example.com',
      'Одинаковое ФИО',
      'teacher',
    );
    otherId = await profile('other@example.com', 'Одинаковое ФИО', 'teacher');
    adminId = await profile('admin@example.com', 'Завуч', 'admin');
    for (final year in [2025, 2026]) {
      await data
          .collection('assignments')
          .create(
            body: {
              'teacher': teacherId,
              'subject': 'Математика',
              'group': 'ПР-21',
              'year': year,
            },
          );
    }
    store = PocketBaseStore(data.baseURL, 'service@example.com', password);
    server = await shelf_io.serve(createHandler(store), '127.0.0.1', 0);
    Future<String> login(String id) async {
      final result = await request(
        'POST',
        '/api/auth/login',
        body: {'profileId': id, 'password': password},
      );
      expect(result.statusCode, 200, reason: result.body);
      final value = jsonDecode(result.body) as Map<String, dynamic>;
      expect(value['user']['profileId'], id);
      return value['token'] as String;
    }

    teacherToken = await login(teacherId);
    otherToken = await login(otherId);
    adminToken = await login(adminId);
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
    'public directory omits email and roles; raw PocketBase cannot bypass Shelf',
    () async {
      final result = await request('GET', '/api/auth/users');
      expect(result.statusCode, 200);
      for (final row in jsonDecode(result.body) as List) {
        expect((row as Map).keys.toSet(), {'id', 'name'});
      }
      expect((await request('GET', path('Сентябрь'))).statusCode, 401);
      expect(
        (await request(
          'GET',
          path('Сентябрь'),
          token: 'invalid-token',
        )).statusCode,
        401,
      );
      expect(
        (await request('GET', path('Сентябрь'), token: otherToken)).statusCode,
        403,
      );
      expect(
        (await request(
          'GET',
          '/api/admin/months/2026/${Uri.encodeComponent('Сентябрь')}',
          token: teacherToken,
        )).statusCode,
        403,
      );
      final raw = PocketBase(data.baseURL)..authStore.save(teacherToken, null);
      addTearDown(raw.close);
      await expectLater(
        raw
            .collection('user_profiles')
            .update(teacherId, body: {'role': 'admin'}),
        throwsA(isA<ClientException>()),
      );
      await expectLater(
        raw.collection('teaching_reports').getFullList(),
        throwsA(isA<ClientException>()),
      );
      await expectLater(
        raw.send('/api/internal/report-write', method: 'POST', body: {}),
        throwsA(isA<ClientException>()),
      );
    },
  );

  test(
    'save, delete one same-day substitution, submit, reject, confirm and lock',
    () async {
      var report = await load('Сентябрь');
      final entry = (report['entries'] as List).single as Map<String, dynamic>;
      entry.addAll({
        'lectureHours': 1.5,
        'practicalHours': 2,
        'courseProjectHours': 3,
        'consultationHours': 4,
        'additionalAssessmentHours': 5,
        'examHours': 6,
      });
      report['substitutions'] = [
        substitution('one', '15.09.2026'),
        substitution('two', '15.09.2026'),
      ];
      report = await change('Сентябрь', 'save', report);
      expect(report['revision'], 1);
      expect(report['totals']['lectureHours'], 1.5);
      final remainingId = report['substitutions'][1]['id'];
      report['substitutions'] = [report['substitutions'][1]];
      report = await change('Сентябрь', 'save', report);
      expect((report['substitutions'] as List).single['id'], remainingId);
      report = await change('Сентябрь', 'submit', report);
      expect(report['status'], 'submitted');
      expect(
        (await request(
          'POST',
          '${path('Сентябрь')}/save',
          token: teacherToken,
          body: report,
        )).statusCode,
        409,
      );
      expect(
        (await request(
          'POST',
          '${path('Сентябрь')}/confirm',
          token: teacherToken,
          body: report,
        )).statusCode,
        403,
      );
      report = await change('Сентябрь', 'reject', report, token: adminToken);
      expect(report['status'], 'draft');
      report = await change('Сентябрь', 'submit', report);
      report = await change('Сентябрь', 'confirm', report, token: adminToken);
      expect(report['status'], 'confirmed');
      expect(report['confirmedById'], adminId);
      final review = await request('GET', path('Сентябрь'), token: adminToken);
      expect(review.statusCode, 200);
      expect(jsonDecode(review.body)['entries'][0]['examHours'], 6);
      expect(
        (await request(
          'POST',
          '${path('Сентябрь')}/reject',
          token: adminToken,
          body: report,
        )).statusCode,
        409,
      );
    },
  );

  test(
    'invalid input does not partially save; calendar dates and assignments validated',
    () async {
      final report = await load('Октябрь');
      report['substitutions'] = [substitution('invalid', '31.02.2026')];
      expect(
        (await request(
          'POST',
          '${path('Октябрь')}/save',
          token: teacherToken,
          body: report,
        )).statusCode,
        422,
      );
      expect((await load('Октябрь'))['revision'], 0);
      report['substitutions'] = [];
      report['entries'][0]['lectureHours'] = -1;
      expect(
        (await request(
          'POST',
          '${path('Октябрь')}/save',
          token: teacherToken,
          body: report,
        )).statusCode,
        422,
      );
      report['entries'][0]['lectureHours'] = 1;
      report['entries'][0]['assignmentId'] = 'unknown';
      expect(
        (await request(
          'POST',
          '${path('Октябрь')}/save',
          token: teacherToken,
          body: report,
        )).statusCode,
        422,
      );
      expect((await load('Октябрь'))['revision'], 0);
    },
  );

  test(
    'concurrent saves accept exactly one version without duplicates',
    () async {
      final report = await load('Ноябрь');
      final results = await Future.wait([
        request(
          'POST',
          '${path('Ноябрь')}/save',
          token: teacherToken,
          body: report,
        ),
        request(
          'POST',
          '${path('Ноябрь')}/save',
          token: teacherToken,
          body: report,
        ),
      ]);
      expect(
        results.map((r) => r.statusCode).toList()..sort(),
        [200, 409],
        reason: results.map((r) => r.body).join('\n'),
      );
      final saved = await load('Ноябрь');
      expect(saved['revision'], 1);
      expect(saved['entries'], hasLength(1));
    },
  );

  test(
    'storage rolls back header and children after a mid-write failure',
    () async {
      final original = await change('Декабрь', 'save', await load('Декабрь'));
      final assignment = original['entries'][0]['assignmentId'];
      await expectLater(
        data.send(
          '/api/internal/report-write',
          method: 'POST',
          body: {
            'teacher': teacherId,
            'month': 'Декабрь',
            'year': 2026,
            'expected_revision': original['revision'],
            'status': 'submitted',
            'entries': [
              {
                'id': original['entries'][0]['id'],
                'assignment': assignment,
                'lecture_hours': 123,
              },
            ],
            'substitutions': [
              {'id': 'unknownrecordid', 'hours': 2},
            ],
          },
        ),
        throwsA(isA<ClientException>()),
      );
      final actual = await load('Декабрь');
      expect(actual, original);
    },
  );

  test('academic year excludes January from previous academic year', () async {
    var january = await load('Январь', 2026);
    january = await change('Январь', 'submit', january);
    expect(january['status'], 'submitted');
    final response = await request(
      'GET',
      '/api/teachers/$teacherId/years/2026',
      token: teacherToken,
    );
    expect((jsonDecode(response.body) as Map).containsKey('Январь'), false);
    var current = await load('Январь', 2027);
    current = await change('Январь', 'save', current, year: 2027);
    final updated = await request(
      'GET',
      '/api/teachers/$teacherId/years/2026',
      token: teacherToken,
    );
    expect(jsonDecode(updated.body)['Январь'], 'draft');
  });

  test('substitutions-only reports can be submitted and locked', () async {
    final endpoint =
        '/api/reports/$otherId/2026/${Uri.encodeComponent('Декабрь')}';
    final response = await request('GET', endpoint, token: otherToken);
    final report = jsonDecode(response.body) as Map<String, dynamic>;
    expect(report['entries'], isEmpty);
    report['substitutions'] = [substitution('only', '12.12.2026')];
    final submitted = await request(
      'POST',
      '$endpoint/submit',
      token: otherToken,
      body: report,
    );
    expect(submitted.statusCode, 200, reason: submitted.body);
    final value = jsonDecode(submitted.body) as Map<String, dynamic>;
    expect(value['status'], 'submitted');
    value['substitutions'] = [];
    expect(
      (await request(
        'POST',
        '$endpoint/save',
        token: otherToken,
        body: value,
      )).statusCode,
      409,
    );
  });
}
