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
  Future<AppUser> login(String profileId, String password) async {
    final result = await _api.request('POST', ['auth', 'login'],
        body: {'profileId': profileId, 'password': password},
        authenticated: false) as Map<String, dynamic>;
    final user = result['user'] as Map<String, dynamic>;
    _api.setToken(result['token'] as String);
    return AppUser(
        id: user['id'] as String,
        profileId: user['profileId'] as String,
        name: user['name'] as String,
        role: UserRole.values.byName(user['role'] as String));
  }

  Future<List<LoginUser>> getUsers() async {
    final rows = await _api.request('GET', ['auth', 'users'],
        authenticated: false) as List;
    return [
      for (final row in rows)
        LoginUser(row['id'] as String, row['name'] as String)
    ];
  }

  void logout() => _api.logout();
}
