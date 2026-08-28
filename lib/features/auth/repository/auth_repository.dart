import '../../../core/pocket_base_service.dart';
import '../models/app_user.dart';

class AuthRepository {
  AuthRepository(this._pb);

  final PocketBaseService _pb;

  Future<AppUser?> login(String name, String password) =>
      _pb.login(name, password);

  Future<List<String>> getTeacherNames() async {
    final users = await _pb.getAllUsers();
    return users.map((u) => u.name).toList();
  }
}
