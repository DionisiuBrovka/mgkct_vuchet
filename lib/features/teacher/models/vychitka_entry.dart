import 'package:freezed_annotation/freezed_annotation.dart';

part 'vychitka_entry.freezed.dart';

enum VychitkaStatus { draft, submitted, confirmed }

@freezed
class VychitkaEntry with _$VychitkaEntry {
  const VychitkaEntry._();

  const factory VychitkaEntry({
    required String id,
    required String teacher,
    required String month,
    required int year,
    required String subject,
    required String group,
    @Default(0) double lek,
    @Default(0) double lrPr,
    @Default(0) double kp,
    @Default(0) double cons,
    @Default(0) double dopKontr,
    @Default(0) double ekz,
    @Default(VychitkaStatus.draft) VychitkaStatus status,
    DateTime? submittedAt,
    DateTime? confirmedAt,
    String? confirmedBy,
  }) = _VychitkaEntry;

  double get totalHours => lek + lrPr + kp + cons + dopKontr + ekz;
}
