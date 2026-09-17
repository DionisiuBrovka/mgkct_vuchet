import '../../../core/api_service.dart';
import '../models/app_user.dart';

class LoginUser {
  const LoginUser(this.id, this.name);
  final String id;
  final String name;
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiService _api;
  Stream<void> get sessionExpired => _api.sessionExpired;
  Future<AppUser> login(String userId, String password) async {
    final result = await _api.request('POST', ['auth', 'login'],
        body: {'userId': userId, 'password': password},
        authenticated: false) as Map<String, dynamic>;
    final user = result['user'] as Map<String, dynamic>;
    return AppUser(
        id: user['id'] as String,
        name: user['name'] as String,
        role: UserRole.values.byName(user['role'] as String));
  }

  Future<List<LoginUser>> getUsers() async {
    final body = await _api.request('GET', ['auth', 'users'],
        authenticated: false) as Map<String, dynamic>;
    final rows = body['users'] as List;
    return [
      for (final row in rows)
        LoginUser(row['id'] as String, row['name'] as String)
    ];
  }

  Future<AppUser> restore() async =>
      _user((await _api.request('GET', ['auth', 'me'])
          as Map<String, dynamic>)['user'] as Map<String, dynamic>);
  Future<void> logout() async {
    try {
      await _api.request('POST', ['auth', 'logout'], body: {});
    } finally {
      _api.logout();
    }
  }

  AppUser _user(Map<String, dynamic> user) => AppUser(
      id: user['id'] as String,
      name: user['name'] as String,
      role: UserRole.values.byName(user['role'] as String));
}
