import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pocketbase/pocketbase.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'src/api_error.dart';
import 'src/auth_service.dart';
import 'src/pocketbase_store.dart';

export 'src/pocketbase_store.dart';

Response jsonResponse(Object value, [int status = 200]) => Response(
  status,
  body: jsonEncode(value),
  headers: const {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  },
);

Future<Map<String, dynamic>> jsonBody(Request request) async {
  if (request.headers['content-type']?.split(';').first != 'application/json')
    throw const ApiError(400, 'Ожидается JSON', code: 'invalid_content_type');
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    if (bytes.length + chunk.length > 1024 * 1024)
      throw const ApiError(
        413,
        'Слишком большой запрос',
        code: 'payload_too_large',
      );
    bytes.addAll(chunk);
  }
  try {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  } on FormatException {
    throw const ApiError(400, 'Некорректный JSON', code: 'malformed_json');
  }
}

String? sessionCookie(Request request) {
  for (final part in (request.headers['cookie'] ?? '').split(';')) {
    final pair = part.trim().split('=');
    if (pair.length == 2 && pair.first == 'mgkct_session') return pair.last;
  }
  return null;
}

String cookie(String value, int maxAge) =>
    'mgkct_session=$value; Path=/api; HttpOnly; SameSite=Strict; Max-Age=$maxAge';
const clearCookie =
    'mgkct_session=; Path=/api; HttpOnly; SameSite=Strict; Max-Age=0';

Handler createHandler(
  PocketBaseStore store, {
  String? staticDirectory,
  Set<String> allowedOrigins = const {},
  AuthService? auth,
}) {
  final service = auth ?? AuthService(store);
  final attempts = <String, List<DateTime>>{};
  final router = Router()
    ..get('/api/health', (Request _) async {
      await store.health();
      return jsonResponse({'status': 'ok'});
    })
    ..get(
      '/api/auth/users',
      (Request _) async => jsonResponse({'users': await service.directory()}),
    )
    ..post('/api/auth/login', (Request request) async {
      final body = await jsonBody(request);
      if (body.keys.toSet().difference({'userId', 'password'}).isNotEmpty ||
          body['userId'] is! String ||
          body['password'] is! String ||
          (body['password'] as String).length > 1024)
        throw const ApiError(
          400,
          'Укажите пользователя и пароль',
          code: 'invalid_request',
        );
      final now = DateTime.now();
      final ip =
          (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)
              ?.remoteAddress
              .address ??
          'local';
      final times = attempts.putIfAbsent(ip, () => []);
      times.removeWhere(
        (time) => time.isBefore(now.subtract(const Duration(minutes: 1))),
      );
      if (times.length >= 20)
        throw const ApiError(
          429,
          'Слишком много попыток. Повторите через минуту',
          code: 'login_rate_limited',
        );
      times.add(now);
      final result = await service.login(
        body['userId'] as String,
        body['password'] as String,
      );
      return jsonResponse({'user': result.actor.toJson()}).change(
        headers: {'set-cookie': cookie(result.credential, result.maxAge)},
      );
    })
    ..get(
      '/api/auth/me',
      (Request request) =>
          jsonResponse({'user': (request.context['actor'] as Actor).toJson()}),
    )
    ..post('/api/auth/logout', (Request request) async {
      await jsonBody(request);
      await service.logout(sessionCookie(request) ?? '');
      return Response(
        204,
        headers: const {'cache-control': 'no-store', 'set-cookie': clearCookie},
      );
    });
  final staticHandler = staticDirectory == null
      ? null
      : createStaticHandler(staticDirectory, defaultDocument: 'index.html');
  return (request) async {
    final origin = request.headers['origin'];
    final cors = <String, String>{};
    if (origin != null && allowedOrigins.contains(origin))
      cors.addAll({
        'access-control-allow-origin': origin,
        'access-control-allow-credentials': 'true',
        'access-control-allow-headers': 'Content-Type',
        'access-control-allow-methods': 'GET, POST, OPTIONS',
        'vary': 'Origin',
      });
    Response response;
    try {
      final api = request.url.path.startsWith('api/');
      if (request.method == 'OPTIONS') {
        response = Response(origin != null && cors.isNotEmpty ? 204 : 403);
      } else if (!api) {
        response = staticHandler == null
            ? Response.notFound('Not found')
            : await staticHandler(request);
      } else {
        const writes = {'POST', 'PUT', 'PATCH', 'DELETE'};
        if (writes.contains(request.method) &&
            (origin == null || !allowedOrigins.contains(origin)))
          throw const ApiError(
            400,
            'Недопустимый Origin',
            code: 'invalid_origin',
          );
        const publicPaths = {
          'api/health',
          'api/auth/users',
          'api/auth/login',
          'api/auth/logout',
        };
        if (!publicPaths.contains(request.url.path)) {
          final result = await service.restore(sessionCookie(request) ?? '');
          request = request.change(context: {'actor': result.actor});
          response = (await router.call(request)).change(
            headers: {'set-cookie': cookie(result.credential, result.maxAge)},
          );
        } else {
          response = await router.call(request);
        }
        if (response.statusCode == 404)
          response = jsonResponse({
            'error': {
              'code': 'route_not_found',
              'message': 'Маршрут не найден',
            },
          }, 404);
      }
    } on ApiError catch (error) {
      response = jsonResponse({
        'error': {'code': error.code, 'message': error.message},
      }, error.status);
      if (error.status == 401)
        response = response.change(headers: {'set-cookie': clearCookie});
    } on ClientException catch (error) {
      response = jsonResponse({
        'error': {
          'code': 'storage_unavailable',
          'message': 'Хранилище временно недоступно',
        },
      }, error.statusCode == 504 ? 504 : 502);
    } on TimeoutException {
      response = jsonResponse({
        'error': {
          'code': 'storage_timeout',
          'message': 'Сервер не ответил вовремя',
        },
      }, 504);
    } catch (error, stack) {
      stderr.writeln('Unhandled server error: ${error.runtimeType}\n$stack');
      response = jsonResponse({
        'error': {
          'code': 'internal_error',
          'message': 'Внутренняя ошибка сервера',
        },
      }, 500);
    }
    return response.change(
      headers: {...cors, 'x-content-type-options': 'nosniff'},
    );
  };
}
