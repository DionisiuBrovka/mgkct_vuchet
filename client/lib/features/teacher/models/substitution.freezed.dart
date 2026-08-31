// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'substitution.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Substitution {
  String get id => throw _privateConstructorUsedError;
  String get teacher => throw _privateConstructorUsedError;
  String get month => throw _privateConstructorUsedError;
  int get year => throw _privateConstructorUsedError;
  String get group => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  double get hours => throw _privateConstructorUsedError;

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubstitutionCopyWith<Substitution> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubstitutionCopyWith<$Res> {
  factory $SubstitutionCopyWith(
          Substitution value, $Res Function(Substitution) then) =
      _$SubstitutionCopyWithImpl<$Res, Substitution>;
  @useResult
  $Res call(
      {String id,
      String teacher,
      String month,
      int year,
      String group,
      String date,
      double hours});
}

/// @nodoc
class _$SubstitutionCopyWithImpl<$Res, $Val extends Substitution>
    implements $SubstitutionCopyWith<$Res> {
  _$SubstitutionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teacher = null,
    Object? month = null,
    Object? year = null,
    Object? group = null,
    Object? date = null,
    Object? hours = null,
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
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      hours: null == hours
          ? _value.hours
          : hours // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SubstitutionImplCopyWith<$Res>
    implements $SubstitutionCopyWith<$Res> {
  factory _$$SubstitutionImplCopyWith(
          _$SubstitutionImpl value, $Res Function(_$SubstitutionImpl) then) =
      __$$SubstitutionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String teacher,
      String month,
      int year,
      String group,
      String date,
      double hours});
}

/// @nodoc
class __$$SubstitutionImplCopyWithImpl<$Res>
    extends _$SubstitutionCopyWithImpl<$Res, _$SubstitutionImpl>
    implements _$$SubstitutionImplCopyWith<$Res> {
  __$$SubstitutionImplCopyWithImpl(
      _$SubstitutionImpl _value, $Res Function(_$SubstitutionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teacher = null,
    Object? month = null,
    Object? year = null,
    Object? group = null,
    Object? date = null,
    Object? hours = null,
  }) {
    return _then(_$SubstitutionImpl(
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
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      hours: null == hours
          ? _value.hours
          : hours // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$SubstitutionImpl implements _Substitution {
  const _$SubstitutionImpl(
      {this.id = '',
      required this.teacher,
      required this.month,
      required this.year,
      required this.group,
      required this.date,
      required this.hours});

  @override
  @JsonKey()
  final String id;
  @override
  final String teacher;
  @override
  final String month;
  @override
  final int year;
  @override
  final String group;
  @override
  final String date;
  @override
  final double hours;

  @override
  String toString() {
    return 'Substitution(id: $id, teacher: $teacher, month: $month, year: $year, group: $group, date: $date, hours: $hours)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubstitutionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teacher, teacher) || other.teacher == teacher) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.hours, hours) || other.hours == hours));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, teacher, month, year, group, date, hours);

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubstitutionImplCopyWith<_$SubstitutionImpl> get copyWith =>
      __$$SubstitutionImplCopyWithImpl<_$SubstitutionImpl>(this, _$identity);
}

abstract class _Substitution implements Substitution {
  const factory _Substitution(
      {final String id,
      required final String teacher,
      required final String month,
      required final int year,
      required final String group,
      required final String date,
      required final double hours}) = _$SubstitutionImpl;

  @override
  String get id;
  @override
  String get teacher;
  @override
  String get month;
  @override
  int get year;
  @override
  String get group;
  @override
  String get date;
  @override
  double get hours;

  /// Create a copy of Substitution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubstitutionImplCopyWith<_$SubstitutionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
