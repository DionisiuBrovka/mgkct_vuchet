import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_service.dart';
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
  int _epoch = 0;
  Future<void> restore() async {
    final epoch = ++_epoch;
    emit(const AuthRestoring());
    try {
      final user = await _repo.restore();
      if (!isClosed && epoch == _epoch) emit(AuthAuthenticated(user));
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        final message = error.toString();
        if (error is ApiException && error.status == 401) {
          emit(const AuthInitial());
        } else {
          emit(AuthRestoreUnavailable(message));
        }
      }
    }
  }

  Future<void> login(String userId, String password) async {
    final epoch = ++_epoch;
    emit(const AuthLoading());
    try {
      final user = await _repo.login(userId, password);
      if (!isClosed && epoch == _epoch) emit(AuthAuthenticated(user));
    } catch (error) {
      if (!isClosed && epoch == _epoch) emit(AuthError(error.toString()));
    }
  }

  Future<void> logout() async {
    ++_epoch;
    emit(const AuthInitial());
    await _repo.logout();
  }

  @override
  Future<void> close() async {
    await _expired.cancel();
    return super.close();
  }
}
