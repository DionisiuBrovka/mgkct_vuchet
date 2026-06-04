import '../../../core/sheets_service.dart';
import '../models/app_user.dart';

class AuthRepository {
  AuthRepository(this._sheets);

  final SheetsService _sheets;

  Future<AppUser?> login(String name, String password) async {
    final users = await _sheets.getUsers();
    try {
      return users.firstWhere(
        (u) => u.name == name && u.password == password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getTeacherNames() async {
    final users = await _sheets.getUsers();
    return users.map((u) => u.name).toList();
  }
}
