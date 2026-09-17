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
  late String teacherId, adminId;
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
}
