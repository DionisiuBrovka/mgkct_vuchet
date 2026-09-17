import 'dart:async';
import 'dart:convert';
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

  void close() {
    _client.close();
    _expired.close();
  }
}
