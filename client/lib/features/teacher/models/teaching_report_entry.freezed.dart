// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'teaching_report_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TeachingReportEntry {
  String get id => throw _privateConstructorUsedError;
  String get teacher => throw _privateConstructorUsedError;
  String get month => throw _privateConstructorUsedError;
  int get year => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  String get group => throw _privateConstructorUsedError;
  String get assignmentId => throw _privateConstructorUsedError;
  double get lectureHours => throw _privateConstructorUsedError;
  double get practicalHours => throw _privateConstructorUsedError;
  double get courseProjectHours => throw _privateConstructorUsedError;
  double get consultationHours => throw _privateConstructorUsedError;
  double get additionalAssessmentHours => throw _privateConstructorUsedError;
  double get examHours => throw _privateConstructorUsedError;
  TeachingReportStatus get status => throw _privateConstructorUsedError;
  DateTime? get submittedAt => throw _privateConstructorUsedError;
  DateTime? get confirmedAt => throw _privateConstructorUsedError;
  String? get confirmedBy => throw _privateConstructorUsedError;

  /// Create a copy of TeachingReportEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeachingReportEntryCopyWith<TeachingReportEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeachingReportEntryCopyWith<$Res> {
  factory $TeachingReportEntryCopyWith(
          TeachingReportEntry value, $Res Function(TeachingReportEntry) then) =
      _$TeachingReportEntryCopyWithImpl<$Res, TeachingReportEntry>;
  @useResult
  $Res call(
      {String id,
      String teacher,
      String month,
      int year,
      String subject,
      String group,
      String assignmentId,
      double lectureHours,
      double practicalHours,
      double courseProjectHours,
      double consultationHours,
      double additionalAssessmentHours,
      double examHours,
      TeachingReportStatus status,
      DateTime? submittedAt,
      DateTime? confirmedAt,
      String? confirmedBy});
}

/// @nodoc
class _$TeachingReportEntryCopyWithImpl<$Res, $Val extends TeachingReportEntry>
    implements $TeachingReportEntryCopyWith<$Res> {
  _$TeachingReportEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeachingReportEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teacher = null,
    Object? month = null,
    Object? year = null,
    Object? subject = null,
    Object? group = null,
    Object? assignmentId = null,
    Object? lectureHours = null,
    Object? practicalHours = null,
    Object? courseProjectHours = null,
    Object? consultationHours = null,
    Object? additionalAssessmentHours = null,
    Object? examHours = null,
    Object? status = null,
    Object? submittedAt = freezed,
    Object? confirmedAt = freezed,
    Object? confirmedBy = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      teacher: null == teacher
          ? _value.teacher
          : teacher // ignore: cast_nullable_to_non_nullable
              as String,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _value.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as String,
      assignmentId: null == assignmentId
          ? _value.assignmentId
          : assignmentId // ignore: cast_nullable_to_non_nullable
              as String,
      lectureHours: null == lectureHours
          ? _value.lectureHours
          : lectureHours // ignore: cast_nullable_to_non_nullable
              as double,
      practicalHours: null == practicalHours
          ? _value.practicalHours
          : practicalHours // ignore: cast_nullable_to_non_nullable
              as double,
      courseProjectHours: null == courseProjectHours
          ? _value.courseProjectHours
          : courseProjectHours // ignore: cast_nullable_to_non_nullable
              as double,
      consultationHours: null == consultationHours
          ? _value.consultationHours
          : consultationHours // ignore: cast_nullable_to_non_nullable
              as double,
      additionalAssessmentHours: null == additionalAssessmentHours
          ? _value.additionalAssessmentHours
          : additionalAssessmentHours // ignore: cast_nullable_to_non_nullable
              as double,
      examHours: null == examHours
          ? _value.examHours
          : examHours // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TeachingReportStatus,
      submittedAt: freezed == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      confirmedAt: freezed == confirmedAt
          ? _value.confirmedAt
          : confirmedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      confirmedBy: freezed == confirmedBy
          ? _value.confirmedBy
          : confirmedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TeachingReportEntryImplCopyWith<$Res>
    implements $TeachingReportEntryCopyWith<$Res> {
  factory _$$TeachingReportEntryImplCopyWith(_$TeachingReportEntryImpl value,
          $Res Function(_$TeachingReportEntryImpl) then) =
      __$$TeachingReportEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String teacher,
      String month,
      int year,
      String subject,
      String group,
      String assignmentId,
      double lectureHours,
      double practicalHours,
      double courseProjectHours,
      double consultationHours,
      double additionalAssessmentHours,
      double examHours,
      TeachingReportStatus status,
      DateTime? submittedAt,
      DateTime? confirmedAt,
      String? confirmedBy});
}

/// @nodoc
class __$$TeachingReportEntryImplCopyWithImpl<$Res>
    extends _$TeachingReportEntryCopyWithImpl<$Res, _$TeachingReportEntryImpl>
    implements _$$TeachingReportEntryImplCopyWith<$Res> {
  __$$TeachingReportEntryImplCopyWithImpl(_$TeachingReportEntryImpl _value,
      $Res Function(_$TeachingReportEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of TeachingReportEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teacher = null,
    Object? month = null,
    Object? year = null,
    Object? subject = null,
    Object? group = null,
    Object? assignmentId = null,
    Object? lectureHours = null,
    Object? practicalHours = null,
    Object? courseProjectHours = null,
    Object? consultationHours = null,
    Object? additionalAssessmentHours = null,
    Object? examHours = null,
    Object? status = null,
    Object? submittedAt = freezed,
    Object? confirmedAt = freezed,
    Object? confirmedBy = freezed,
  }) {
    return _then(_$TeachingReportEntryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      teacher: null == teacher
          ? _value.teacher
          : teacher // ignore: cast_nullable_to_non_nullable
              as String,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _value.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as String,
      assignmentId: null == assignmentId
          ? _value.assignmentId
          : assignmentId // ignore: cast_nullable_to_non_nullable
              as String,
      lectureHours: null == lectureHours
          ? _value.lectureHours
          : lectureHours // ignore: cast_nullable_to_non_nullable
              as double,
      practicalHours: null == practicalHours
          ? _value.practicalHours
          : practicalHours // ignore: cast_nullable_to_non_nullable
              as double,
      courseProjectHours: null == courseProjectHours
          ? _value.courseProjectHours
          : courseProjectHours // ignore: cast_nullable_to_non_nullable
              as double,
      consultationHours: null == consultationHours
          ? _value.consultationHours
          : consultationHours // ignore: cast_nullable_to_non_nullable
              as double,
      additionalAssessmentHours: null == additionalAssessmentHours
          ? _value.additionalAssessmentHours
          : additionalAssessmentHours // ignore: cast_nullable_to_non_nullable
              as double,
      examHours: null == examHours
          ? _value.examHours
          : examHours // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TeachingReportStatus,
      submittedAt: freezed == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      confirmedAt: freezed == confirmedAt
          ? _value.confirmedAt
          : confirmedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      confirmedBy: freezed == confirmedBy
          ? _value.confirmedBy
          : confirmedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$TeachingReportEntryImpl extends _TeachingReportEntry {
  const _$TeachingReportEntryImpl(
      {required this.id,
      required this.teacher,
      required this.month,
      required this.year,
      required this.subject,
      required this.group,
      this.assignmentId = '',
      this.lectureHours = 0,
      this.practicalHours = 0,
      this.courseProjectHours = 0,
      this.consultationHours = 0,
      this.additionalAssessmentHours = 0,
      this.examHours = 0,
      this.status = TeachingReportStatus.draft,
      this.submittedAt,
      this.confirmedAt,
      this.confirmedBy})
      : super._();

  @override
  final String id;
  @override
  final String teacher;
  @override
  final String month;
  @override
  final int year;
  @override
  final String subject;
  @override
  final String group;
  @override
  @JsonKey()
  final String assignmentId;
  @override
  @JsonKey()
  final double lectureHours;
  @override
  @JsonKey()
  final double practicalHours;
  @override
  @JsonKey()
  final double courseProjectHours;
  @override
  @JsonKey()
  final double consultationHours;
  @override
  @JsonKey()
  final double additionalAssessmentHours;
  @override
  @JsonKey()
  final double examHours;
  @override
  @JsonKey()
  final TeachingReportStatus status;
  @override
  final DateTime? submittedAt;
  @override
  final DateTime? confirmedAt;
  @override
  final String? confirmedBy;

  @override
  String toString() {
    return 'TeachingReportEntry(id: $id, teacher: $teacher, month: $month, year: $year, subject: $subject, group: $group, assignmentId: $assignmentId, lectureHours: $lectureHours, practicalHours: $practicalHours, courseProjectHours: $courseProjectHours, consultationHours: $consultationHours, additionalAssessmentHours: $additionalAssessmentHours, examHours: $examHours, status: $status, submittedAt: $submittedAt, confirmedAt: $confirmedAt, confirmedBy: $confirmedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeachingReportEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teacher, teacher) || other.teacher == teacher) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.assignmentId, assignmentId) ||
                other.assignmentId == assignmentId) &&
            (identical(other.lectureHours, lectureHours) ||
                other.lectureHours == lectureHours) &&
            (identical(other.practicalHours, practicalHours) ||
                other.practicalHours == practicalHours) &&
            (identical(other.courseProjectHours, courseProjectHours) ||
                other.courseProjectHours == courseProjectHours) &&
            (identical(other.consultationHours, consultationHours) ||
                other.consultationHours == consultationHours) &&
            (identical(other.additionalAssessmentHours,
                    additionalAssessmentHours) ||
                other.additionalAssessmentHours == additionalAssessmentHours) &&
            (identical(other.examHours, examHours) ||
                other.examHours == examHours) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.confirmedAt, confirmedAt) ||
                other.confirmedAt == confirmedAt) &&
            (identical(other.confirmedBy, confirmedBy) ||
                other.confirmedBy == confirmedBy));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      teacher,
      month,
      year,
      subject,
      group,
      assignmentId,
      lectureHours,
      practicalHours,
      courseProjectHours,
      consultationHours,
      additionalAssessmentHours,
      examHours,
      status,
      submittedAt,
      confirmedAt,
      confirmedBy);

  /// Create a copy of TeachingReportEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeachingReportEntryImplCopyWith<_$TeachingReportEntryImpl> get copyWith =>
      __$$TeachingReportEntryImplCopyWithImpl<_$TeachingReportEntryImpl>(
          this, _$identity);
}

abstract class _TeachingReportEntry extends TeachingReportEntry {
  const factory _TeachingReportEntry(
      {required final String id,
      required final String teacher,
      required final String month,
      required final int year,
      required final String subject,
      required final String group,
      final String assignmentId,
      final double lectureHours,
      final double practicalHours,
      final double courseProjectHours,
      final double consultationHours,
      final double additionalAssessmentHours,
      final double examHours,
      final TeachingReportStatus status,
      final DateTime? submittedAt,
      final DateTime? confirmedAt,
      final String? confirmedBy}) = _$TeachingReportEntryImpl;
  const _TeachingReportEntry._() : super._();

  @override
  String get id;
  @override
  String get teacher;
  @override
  String get month;
  @override
  int get year;
  @override
  String get subject;
  @override
  String get group;
  @override
  String get assignmentId;
  @override
  double get lectureHours;
  @override
  double get practicalHours;
  @override
  double get courseProjectHours;
  @override
  double get consultationHours;
  @override
  double get additionalAssessmentHours;
  @override
  double get examHours;
  @override
  TeachingReportStatus get status;
  @override
  DateTime? get submittedAt;
  @override
  DateTime? get confirmedAt;
  @override
  String? get confirmedBy;

  /// Create a copy of TeachingReportEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeachingReportEntryImplCopyWith<_$TeachingReportEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
