import 'package:equatable/equatable.dart';

import '../models/app_user.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class AuthRestoreUnavailable extends AuthState {
  const AuthRestoreUnavailable(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
  @override
  List<Object?> get props => [user.id, user.name, user.role];
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
