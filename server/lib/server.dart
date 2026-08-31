import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pocketbase/pocketbase.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'src/api_error.dart';
import 'src/pocketbase_store.dart';
import 'src/report_service.dart';
export 'src/pocketbase_store.dart';

Response jsonResponse(Object value, [int status = 200]) => Response(
  status,
  body: jsonEncode(value),
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  },
);

Future<Map<String, dynamic>> jsonBody(Request request) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    if (bytes.length + chunk.length > 1024 * 1024) {
      throw const ApiError(413, 'Слишком большой запрос');
    }
    bytes.addAll(chunk);
  }
  try {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  } on FormatException {
    throw const ApiError(400, 'Некорректный JSON');
  }
}

Handler createHandler(
  PocketBaseStore store, {
  String? staticDirectory,
  Set<String> allowedOrigins = const {},
}) {
  final reports = ReportService(store);
  Map<String, dynamic> actor(Request request) =>
      request.context['actor'] as Map<String, dynamic>;
  int year(String value) =>
      int.tryParse(value) ?? (throw const ApiError(400, 'Некорректный год'));
  final router = Router();
  router.get('/api/health', (Request request) async {
    await store.health();
    return jsonResponse({'status': 'ok'});
  });
  router.get('/api/auth/users', (Request request) async {
    final users = await store.list('users');
    return jsonResponse(
      [
        for (final user in users)
          {'id': user.id, 'name': user.data['display_name']},
      ]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String)),
    );
  });
  final attempts = <String, List<DateTime>>{};
  router.post('/api/auth/login', (Request request) async {
    final now = DateTime.now();
    attempts.removeWhere(
      (_, times) =>
          times.last.isBefore(now.subtract(const Duration(minutes: 1))),
    );
    final ip =
        (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)
            ?.remoteAddress
            .address ??
        'local';
    if (!attempts.containsKey(ip) && attempts.length >= 10000) {
      throw const ApiError(
        429,
        'Слишком много попыток. Повторите через минуту',
      );
    }
    final times = attempts.putIfAbsent(ip, () => []);
    times.removeWhere(
      (time) => time.isBefore(now.subtract(const Duration(minutes: 1))),
    );
    if (times.length >= 20) {
      throw const ApiError(
        429,
        'Слишком много попыток. Повторите через минуту',
      );
    }
    times.add(now);
    final body = await jsonBody(request);
    if (body['profileId'] is! String ||
        body['password'] is! String ||
        (body['password'] as String).length > 1024) {
      throw const ApiError(400, 'Укажите пользователя и пароль');
    }
    return jsonResponse(
      await store.login(
        body['profileId'] as String,
        body['password'] as String,
      ),
    );
  });
  router.get('/api/auth/me', (Request request) => jsonResponse(actor(request)));
  router.get(
    '/api/teachers/<teacher>/years/<value>',
    (Request request, String teacher, String value) async => jsonResponse(
      await reports.statuses(actor(request), teacher, year(value)),
    ),
  );
  router.get(
    '/api/admin/months/<value>/<month>',
    (Request request, String value, String month) async => jsonResponse(
      await reports.overview(
        actor(request),
        Uri.decodeComponent(month),
        year(value),
      ),
    ),
  );
  router.get(
    '/api/reports/<teacher>/<value>/<month>',
    (Request request, String teacher, String value, String month) async =>
        jsonResponse(
          await reports.report(
            actor(request),
            teacher,
            Uri.decodeComponent(month),
            year(value),
          ),
        ),
  );
  router.post(
    '/api/reports/<teacher>/<value>/<month>/<action>',
    (
      Request request,
      String teacher,
      String value,
      String month,
      String action,
    ) async => jsonResponse(
      await reports.change(
        actor(request),
        teacher,
        Uri.decodeComponent(month),
        year(value),
        action,
        await jsonBody(request),
      ),
    ),
  );
  final staticHandler = staticDirectory == null
      ? null
      : createStaticHandler(staticDirectory, defaultDocument: 'index.html');

  return (request) async {
    final origin = request.headers['origin'];
    final cors = <String, String>{};
    if (origin != null && allowedOrigins.contains(origin)) {
      cors.addAll({
        'access-control-allow-origin': origin,
        'vary': 'Origin',
        'access-control-allow-headers': 'Authorization, Content-Type',
        'access-control-allow-methods': 'GET, POST, OPTIONS',
      });
    }
    Response response;
    try {
      if (request.method == 'OPTIONS') {
        response = Response(origin == null || cors.isNotEmpty ? 204 : 403);
      } else if (!request.url.path.startsWith('api/')) {
        response = staticHandler == null
            ? Response.notFound('Not found')
            : await staticHandler(request);
      } else {
        const publicPaths = {'api/health', 'api/auth/users', 'api/auth/login'};
        if (!publicPaths.contains(request.url.path)) {
          final header = request.headers['authorization'] ?? '';
          final user = await store.authenticate(
            header.startsWith('Bearer ') ? header.substring(7) : '',
          );
          request = request.change(context: {'actor': user});
        }
        response = await router.call(request);
        if (response.statusCode == 404) {
          response = jsonResponse({'message': 'Маршрут не найден'}, 404);
        }
      }
    } on ApiError catch (error) {
      response = jsonResponse({'message': error.message}, error.status);
    } on ClientException catch (error) {
      response = error.statusCode == 409
          ? jsonResponse({'message': 'Отчёт уже изменён. Обновите данные'}, 409)
          : jsonResponse({'message': 'Хранилище временно недоступно'}, 502);
    } on TimeoutException {
      response = jsonResponse({'message': 'Сервер не ответил вовремя'}, 504);
    } catch (error, stack) {
      // No request bodies, credentials or tokens are logged.
      stderr.writeln('Unhandled server error: ${error.runtimeType}\n$stack');
      response = jsonResponse({'message': 'Внутренняя ошибка сервера'}, 500);
    }
    return response.change(
      headers: {...cors, 'x-content-type-options': 'nosniff'},
    );
  };
}
