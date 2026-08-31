import 'package:freezed_annotation/freezed_annotation.dart';

part 'substitution.freezed.dart';

@freezed
class Substitution with _$Substitution {
  const factory Substitution({
    @Default('') String id,
    required String teacher,
    required String month,
    required int year,
    required String group,
    required String date,
    required double hours,
  }) = _Substitution;
}
