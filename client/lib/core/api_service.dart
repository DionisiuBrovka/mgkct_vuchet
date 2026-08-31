import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, [this.status = 0]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class ApiService {
  ApiService(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  String? _token;
  final _expired = StreamController<void>.broadcast();
  Stream<void> get sessionExpired => _expired.stream;
  void setToken(String token) => _token = token;
  void logout() => _token = null;

  Future<dynamic> request(String method, List<String> path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    final uri = Uri.parse(baseUrl).replace(pathSegments: ['api', ...path]);
    try {
      final response = await _client
          .send(http.Request(method, uri)
            ..headers.addAll({
              'Content-Type': 'application/json',
              if (authenticated && _token != null)
                'Authorization': 'Bearer $_token'
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
          logout();
          _expired.add(null);
        }
        throw ApiException(
            value is Map
                ? value['message']?.toString() ?? 'Ошибка сервера'
                : 'Ошибка сервера',
            response.statusCode);
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
