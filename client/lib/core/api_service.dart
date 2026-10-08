import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, [this.status = 0, this.code = 'network']);
  final String message;
  final int status;
  final String code;
  @override
  String toString() => message;
}

class ApiService {
  ApiService(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final _expired = StreamController<void>.broadcast();
  Stream<void> get sessionExpired => _expired.stream;
  // Authentication is an HttpOnly same-origin cookie; client code never owns it.
  @Deprecated('Session credentials are HttpOnly cookies.')
  void setToken(String _) {}
  void logout() {}

  Future<dynamic> request(String method, List<String> path,
      {Map<String, dynamic>? body,
      bool authenticated = true,
      Map<String, String>? query}) async {
    final uri = Uri.parse(baseUrl)
        .replace(pathSegments: ['api', ...path], queryParameters: query);
    try {
      final response = await _client
          .send(http.Request(method, uri)
            ..headers.addAll({
              'Content-Type': 'application/json',
            })
            ..body = body == null ? '' : jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      final text = await response.stream
          .bytesToString()
          .timeout(const Duration(seconds: 20));
      dynamic value;
      try {
        value = jsonDecode(text);
      } on FormatException {
        throw const ApiException('Некорректный ответ сервера');
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && authenticated) {
          _expired.add(null);
        }
        throw ApiException(
            value is Map
                ? ((value['error'] as Map?)?['message']?.toString() ??
                    value['message']?.toString() ??
                    'Ошибка сервера')
                : 'Ошибка сервера',
            response.statusCode,
            value is Map
                ? ((value['error'] as Map?)?['code']?.toString() ??
                    'http_error')
                : 'http_error');
      }
      return value;
    } on TimeoutException {
      throw const ApiException(
          'Сервер не ответил вовремя. Введённые данные сохранены в форме');
    } on http.ClientException {
      throw const ApiException('Нет связи с сервером');
    }
  }

  Future<Uint8List> download(
      List<String> path, Map<String, String> query) async {
    final uri = Uri.parse(baseUrl)
        .replace(pathSegments: ['api', ...path], queryParameters: query);
    try {
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        if (response.statusCode == 401) _expired.add(null);
        String message = 'Не удалось выгрузить статистику. Повторите попытку.';
        try {
          final value = jsonDecode(response.body) as Map;
          message = (value['error'] as Map?)?['message']?.toString() ?? message;
        } on FormatException {/* Non-JSON proxy error. */}
        throw ApiException(message, response.statusCode);
      }
      if (!(response.headers['content-type'] ?? '')
          .contains('spreadsheetml.sheet')) {
        throw const ApiException('Сервер вернул неверный формат файла');
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const ApiException(
          'Выгрузка заняла слишком много времени. Уточните фильтры.');
    } on http.ClientException {
      throw const ApiException('Нет связи с сервером. Повторите выгрузку.');
    }
  }

  void close() {
    _client.close();
    _expired.close();
  }
}
