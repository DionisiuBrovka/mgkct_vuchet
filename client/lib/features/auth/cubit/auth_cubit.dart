import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthInitial()) {
    _expired = _repo.sessionExpired.listen((_) {
      if (!isClosed) emit(const AuthInitial());
    });
  }
  final AuthRepository _repo;
  late final StreamSubscription<void> _expired;
  Future<void> login(String profileId, String password) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.login(profileId, password);
      if (!isClosed) emit(AuthAuthenticated(user));
    } catch (error) {
      if (!isClosed) emit(AuthError(error.toString()));
    }
  }

  void logout() {
    _repo.logout();
    emit(const AuthInitial());
  }

  @override
  Future<void> close() async {
    await _expired.cancel();
    return super.close();
  }
}
