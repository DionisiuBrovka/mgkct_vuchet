import 'package:flutter/material.dart';

import '../../core/decimal_input.dart';
import '../hour_descriptions.dart';

class HoursInputField extends StatefulWidget {
  const HoursInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label, value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<HoursInputField> createState() => _HoursInputFieldState();
}

class _HoursInputFieldState extends State<HoursInputField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(HoursInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _controller.text != widget.value) {
      // Controller notifications must not invalidate the parent Form during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focus.hasFocus && _controller.text != widget.value) {
          _controller.text = widget.value;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String? _validation(String? value) {
    final decimal = DecimalInput.tryParse(value ?? '');
    if (decimal == null) {
      return (value ?? '').endsWith(',') || (value ?? '').endsWith('.')
          ? 'Допишите дробную часть'
          : 'Введите число от 0, например 1,5';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _controller,
        focusNode: _focus,
        enabled: widget.enabled,
        validator: _validation,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          label: Tooltip(
            message: hourDescriptions[widget.label] ?? widget.label,
            child: Text(widget.label),
          ),
          hintText: '0',
          suffixText: 'ч',
          errorMaxLines: 2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onChanged: widget.onChanged,
      );
}
