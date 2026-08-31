import 'package:freezed_annotation/freezed_annotation.dart';

part 'assignment.freezed.dart';

@freezed
class Assignment with _$Assignment {
  const factory Assignment({
    required String teacher,
    required String subject,
    required String group,
    required int year,
  }) = _Assignment;
}
