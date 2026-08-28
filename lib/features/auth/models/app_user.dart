import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

enum UserRole { teacher, admin }

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String profileId,
    required String name,
    required UserRole role,
  }) = _AppUser;
}
