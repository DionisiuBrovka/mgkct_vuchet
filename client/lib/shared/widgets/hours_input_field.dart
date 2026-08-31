import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../hour_descriptions.dart';

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
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
    _focusNode.addListener(_syncFromWidget);
  }

  @override
  void didUpdateWidget(HoursInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromWidget();
  }

  void _syncFromWidget() {
    // Если значение изменилось извне (например, после повторной загрузки
    // месяца) и поле не в фокусе — синхронизируем контроллер, чтобы не
    // показывать устаревшие данные.
    if (!_focusNode.hasFocus && _ctrl.text != _format(widget.value)) {
      _ctrl.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_syncFromWidget);
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  String _format(double v) => v == 0 ? '' : v.toString();

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
      focusNode: _focusNode,
      enabled: widget.enabled,
      validator: _validate,
      decoration: InputDecoration(
        label: Tooltip(
          message: hourDescriptions[widget.label] ?? widget.label,
          child: Text(widget.label),
        ),
        hintText: '0',
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
