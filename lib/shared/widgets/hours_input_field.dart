import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HoursInputField extends StatefulWidget {
  const HoursInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.maxHours = 999,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final double maxHours;

  @override
  State<HoursInputField> createState() => _HoursInputFieldState();
}

class _HoursInputFieldState extends State<HoursInputField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value == 0 ? '' : widget.value.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    if (v == null || v.isEmpty) return null; // 0 часов — допустимо
    final parsed = double.tryParse(v);
    if (parsed == null) return '?';
    if (parsed < 0) return '< 0';
    if (parsed > widget.maxHours) return '> ${widget.maxHours.toInt()}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      enabled: widget.enabled,
      validator: _validate,
      decoration: InputDecoration(
        labelText: widget.label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        isDense: true,
        errorStyle: const TextStyle(fontSize: 11, height: 1.2),
      ),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (v) {
        final parsed = double.tryParse(v) ?? 0;
        widget.onChanged(parsed);
      },
    );
  }
}
