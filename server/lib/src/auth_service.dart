import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pocketbase/pocketbase.dart';

import 'api_error.dart';
import 'pocketbase_store.dart';

class Actor {
  const Actor(this.id, this.name, this.role);
  final String id;
  final String name;
  final String role;

  Map<String, String> toJson() => {'id': id, 'name': name, 'role': role};
}

class AuthResult {
  const AuthResult(this.actor, this.credential, this.maxAge);
  final Actor actor;
  final String credential;
  final int maxAge;
}

class AuthService {
  AuthService(this._store, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _random = random ?? Random.secure();

  static const _idle = Duration(hours: 12);
  static const _absolute = Duration(days: 30);
  final PocketBaseStore _store;
  final DateTime Function() _clock;
  final Random _random;

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
  String _credential() => base64UrlEncode(
    List<int>.generate(32, (_) => _random.nextInt(256)),
  ).replaceAll('=', '');
  String _date(DateTime value) => value.toUtc().toIso8601String();

  Actor _actor(RecordModel user) {
    final role = user.data['role'];
    final name = user.data['name'];
    if (role != 'teacher' && role != 'admin' ||
        name is! String ||
        name.isEmpty) {
      throw const ApiError(
        401,
        'Сессия недействительна',
        code: 'session_invalid',
      );
    }
    return Actor(user.id, name, role as String);
  }

  bool _active(RecordModel user) => user.data['is_active'] == true;
  int _version(RecordModel user) =>
      (user.data['auth_version'] as num?)?.toInt() ?? 0;

  Future<List<Map<String, String>>> directory() async {
    final users = await _store.list('users', filter: 'is_active = true');
    return [
      for (final user in users)
        if (user.data['name'] is String)
          {'id': user.id, 'name': user.data['name'] as String},
    ]..sort((left, right) => left['name']!.compareTo(right['name']!));
  }

  Future<AuthResult> login(String id, String password) async {
    RecordModel user;
    try {
      user = await _store.get('users', id);
      if (!_active(user) || _version(user) < 1)
        throw const ApiError(
          401,
          'Неверное имя или пароль',
          code: 'invalid_credentials',
        );
      await _store.verifyPassword(user.data['email'] as String, password, id);
      // Re-read after password verification so a concurrent block/role change wins.
      user = await _store.get('users', id);
      if (!_active(user) || _version(user) < 1)
        throw const ApiError(
          401,
          'Неверное имя или пароль',
          code: 'invalid_credentials',
        );
    } on ClientException catch (error) {
      if (error.statusCode == 400 ||
          error.statusCode == 401 ||
          error.statusCode == 404) {
        throw const ApiError(
          401,
          'Неверное имя или пароль',
          code: 'invalid_credentials',
        );
      }
      rethrow;
    }
    final now = _clock();
    final credential = _credential();
    await _store.createSession({
      'user': user.id,
      'token_hash': _hash(credential),
      'auth_version': _version(user),
      'created_at': _date(now),
      'last_seen_at': _date(now),
      'expires_at': _date(now.add(_absolute)),
    });
    return AuthResult(_actor(user), credential, _absolute.inSeconds);
  }

  Future<AuthResult> restore(String credential) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(credential)) {
      throw const ApiError(
        401,
        'Сессия истекла. Войдите снова',
        code: 'session_invalid',
      );
    }
    final sessions = await _store.list(
      'app_sessions',
      filter: 'token_hash = {:hash}',
      params: {'hash': _hash(credential)},
    );
    if (sessions.length != 1)
      throw const ApiError(
        401,
        'Сессия истекла. Войдите снова',
        code: 'session_invalid',
      );
    final session = sessions.single;
    final now = _clock();
    DateTime parse(dynamic value) => DateTime.parse(value as String).toUtc();
    final revoked = session.data['revoked_at'];
    if (revoked is String && revoked.isNotEmpty ||
        !now.isBefore(parse(session.data['expires_at'])) ||
        now.difference(parse(session.data['last_seen_at'])) >= _idle) {
      throw const ApiError(
        401,
        'Сессия истекла. Войдите снова',
        code: 'session_invalid',
      );
    }
    RecordModel user;
    try {
      user = await _store.get('users', session.data['user'] as String);
    } on ClientException catch (error) {
      if (error.statusCode == 404)
        throw const ApiError(
          401,
          'Сессия истекла. Войдите снова',
          code: 'session_invalid',
        );
      rethrow;
    }
    if (!_active(user) ||
        _version(user) != (session.data['auth_version'] as num?)?.toInt()) {
      throw const ApiError(
        401,
        'Сессия истекла. Войдите снова',
        code: 'session_invalid',
      );
    }
    await _store.update('app_sessions', session.id, {
      'last_seen_at': _date(now),
    });
    final remaining = sessionExpiry(now, parse(session.data['expires_at']));
    return AuthResult(_actor(user), credential, remaining);
  }

  int sessionExpiry(DateTime now, DateTime absolute) {
    final seconds = absolute.difference(now).inSeconds;
    return seconds < _idle.inSeconds ? seconds : _idle.inSeconds;
  }

  Future<void> logout(String credential) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(credential)) return;
    final sessions = await _store.list(
      'app_sessions',
      filter: 'token_hash = {:hash}',
      params: {'hash': _hash(credential)},
    );
    if (sessions.length == 1 &&
        (sessions.single.data['revoked_at'] == null ||
            sessions.single.data['revoked_at'] == '')) {
      await _store.update('app_sessions', sessions.single.id, {
        'revoked_at': _date(_clock()),
      });
    }
  }
}
