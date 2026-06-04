import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthInitial());

  final AuthRepository _repo;

  Future<void> login(String name, String password) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.login(name, password);
      if (user == null) {
        emit(const AuthError('Неверное имя или пароль'));
      } else {
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  void logout() => emit(const AuthInitial());
}
