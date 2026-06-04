import 'package:freezed_annotation/freezed_annotation.dart';

part 'zamena.freezed.dart';

@freezed
class Zamena with _$Zamena {
  const factory Zamena({
    required String teacher,
    required String month,
    required int year,
    required String group,
    required String date,
    required double hours,
  }) = _Zamena;
}
