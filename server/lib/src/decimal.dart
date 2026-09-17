import 'api_error.dart';

class Decimal {
  const Decimal(this.coefficient, this.scale);
  final BigInt coefficient;
  final int scale;

  static final _valid = RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$');
  factory Decimal.parse(Object? value) {
    if (value is! String || !_valid.hasMatch(value)) {
      throw const ApiError(
        422,
        'Некорректное число часов',
        code: 'invalid_decimal',
      );
    }
    final parts = value.split('.');
    return Decimal(
      BigInt.parse(parts.join()),
      parts.length == 2 ? parts[1].length : 0,
    );
  }
  Decimal operator +(Decimal other) {
    final target = scale > other.scale ? scale : other.scale;
    BigInt shift(BigInt value, int count) => value * BigInt.from(10).pow(count);
    return Decimal(
      shift(coefficient, target - scale) +
          shift(other.coefficient, target - other.scale),
      target,
    )._normalized();
  }

  Decimal _normalized() {
    var value = coefficient;
    var digits = scale;
    while (digits > 0 && value % BigInt.from(10) == BigInt.zero) {
      value ~/= BigInt.from(10);
      digits--;
    }
    return Decimal(value, digits);
  }

  @override
  String toString() {
    final value = _normalized();
    final raw = value.coefficient.toString();
    if (value.scale == 0) return raw;
    final padded = raw.padLeft(value.scale + 1, '0');
    return '${padded.substring(0, padded.length - value.scale)}.${padded.substring(padded.length - value.scale)}';
  }
}

Decimal sum(Iterable<Decimal> values) =>
    values.fold(Decimal(BigInt.zero, 0), (total, value) => total + value);
