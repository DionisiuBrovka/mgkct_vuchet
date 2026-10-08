import 'package:flutter_test/flutter_test.dart';
import 'package:mgkct_teaching_hours/core/decimal_input.dart';

void main() {
  test('keeps long decimals exact and accepts comma input', () {
    final long = DecimalInput.tryParse('1000,125000000000000000001')!;
    expect(long.canonical, '1000.125000000000000000001');
  });

  test('adds decimal tenths without binary floating point rounding', () {
    final result =
        DecimalInput.tryParse('0,1')! + DecimalInput.tryParse('0.2')!;
    expect(result.canonical, '0.3');
  });

  test('does not treat an incomplete fraction as zero', () {
    expect(DecimalInput.tryParse('1,'), isNull);
    expect(DecimalInput.tryParse(''), isNotNull);
  });
}
