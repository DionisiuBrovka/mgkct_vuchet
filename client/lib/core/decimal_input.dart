/// Exact decimal arithmetic for editable form fields.
///
/// The server remains authoritative; this only preserves text and renders a
/// preview without converting through IEEE-754 doubles.
class DecimalInput {
  const DecimalInput._(this.coefficient, this.scale);

  final BigInt coefficient;
  final int scale;

  static DecimalInput? tryParse(String source, {bool allowBlank = true}) {
    final text = source.replaceAll(',', '.');
    if (text.isEmpty && allowBlank) return DecimalInput._(BigInt.zero, 0);
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) return null;
    final parts = text.split('.');
    return DecimalInput._(
        BigInt.parse(parts.join()), parts.length == 2 ? parts[1].length : 0);
  }

  DecimalInput operator +(DecimalInput other) {
    final common = scale > other.scale ? scale : other.scale;
    BigInt shift(BigInt value, int amount) =>
        value * BigInt.from(10).pow(amount);
    return DecimalInput._(
      shift(coefficient, common - scale) +
          shift(other.coefficient, common - other.scale),
      common,
    );
  }

  int compareTo(DecimalInput other) {
    final common = scale > other.scale ? scale : other.scale;
    return (coefficient * BigInt.from(10).pow(common - scale)).compareTo(
        other.coefficient * BigInt.from(10).pow(common - other.scale));
  }

  String get canonical {
    if (coefficient == BigInt.zero) return '0';
    final digits = coefficient.toString().padLeft(scale + 1, '0');
    if (scale == 0) return digits;
    final whole = digits.substring(0, digits.length - scale);
    final fraction = digits
        .substring(digits.length - scale)
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }
}
