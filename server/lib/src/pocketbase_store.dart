import 'package:pocketbase/pocketbase.dart';
import 'api_error.dart';

class PocketBaseStore {
  PocketBaseStore(this.url, this.email, this.password)
    : _admin = PocketBase(url, reuseHTTPClient: true);
  final String url;
  final String email;
  final String password;
  final PocketBase _admin;
  Future<void>? _authentication;

  Future<void> _ready() async {
    if (_admin.authStore.isValid) return;
    await (_authentication ??= _admin
        .collection('_superusers')
        .authWithPassword(email, password)
        .timeout(const Duration(seconds: 15))
        .then((_) {})
        .whenComplete(() => _authentication = null));
  }

  Future<T> _call<T>(Future<T> Function(PocketBase) operation) async {
    await _ready();
    try {
      return await operation(_admin).timeout(const Duration(seconds: 15));
    } on ClientException catch (error) {
      if (error.statusCode == 401) {
        _admin.authStore.clear();
        await _ready();
        return operation(_admin).timeout(const Duration(seconds: 15));
      }
      rethrow;
    }
  }

  Future<List<RecordModel>> list(
    String collection, {
    String filter = '',
    Map<String, Object?> params = const {},
    String expand = '',
  }) => _call(
    (pb) => pb
        .collection(collection)
        .getFullList(filter: pb.filter(filter, params), expand: expand),
  );

  Future<RecordModel> get(String collection, String id) =>
      _call((pb) => pb.collection(collection).getOne(id));

  Future<void> writeReport(Map<String, dynamic> body) => _call((pb) async {
    await pb.send('/api/internal/report-write', method: 'POST', body: body);
  });

  Future<Map<String, dynamic>> login(String profileId, String password) async {
    RecordModel profile;
    try {
      profile = await get('user_profiles', profileId);
    } on ClientException {
      throw const ApiError(401, 'Неверное имя или пароль');
    }
    final userClient = PocketBase(url);
    try {
      final auth = await userClient
          .collection('users')
          .authWithPassword(profile.data['email'] as String, password)
          .timeout(const Duration(seconds: 15));
      if (auth.record.id != profile.data['user']) {
        throw const ApiError(401, 'Неверное имя или пароль');
      }
      return {'token': auth.token, 'user': actor(profile, auth.record.id)};
    } on ClientException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        throw const ApiError(401, 'Неверное имя или пароль');
      }
      rethrow;
    } finally {
      userClient.close();
    }
  }

  Future<Map<String, dynamic>> authenticate(String token) async {
    if (token.isEmpty) throw const ApiError(401, 'Войдите в приложение');
    final client = PocketBase(url);
    client.authStore.save(token, null);
    try {
      final auth = await client
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 15));
      final profiles = await list(
        'user_profiles',
        filter: 'user = {:id}',
        params: {'id': auth.record.id},
      );
      if (profiles.length != 1) {
        throw const ApiError(403, 'Профиль пользователя не настроен');
      }
      return actor(profiles.single, auth.record.id);
    } on ClientException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        throw const ApiError(401, 'Сессия истекла. Войдите снова');
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> actor(RecordModel profile, String userId) {
    final role = profile.data['role'];
    if (role != 'teacher' && role != 'admin') {
      throw const ApiError(403, 'Неизвестная роль');
    }
    return {
      'id': userId,
      'profileId': profile.id,
      'name': profile.data['display_name'],
      'role': role,
    };
  }

  Future<void> health() => _call((pb) async {
    await pb.health.check();
  });
  void close() => _admin.close();
}
