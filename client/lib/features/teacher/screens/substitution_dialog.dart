import 'package:flutter/material.dart';
import '../../../core/decimal_input.dart';
import '../../../shared/widgets/hours_input_field.dart';
import '../models/editable_report.dart';

class SubstitutionDialog extends StatefulWidget {
  const SubstitutionDialog(
      {super.key, required this.year, required this.month, this.original});
  final int year, month;
  final EditableSubstitution? original;
  @override
  State<SubstitutionDialog> createState() => _SubstitutionDialogState();
}

class _SubstitutionDialogState extends State<SubstitutionDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _description, _dateText;
  DateTime? _date;
  late String _hours;
  @override
  void initState() {
    super.initState();
    _description =
        TextEditingController(text: widget.original?.description ?? '');
    _date = DateTime.tryParse(widget.original?.date ?? '');
    _dateText =
        TextEditingController(text: _date == null ? '' : _displayDate(_date!));
    _hours = widget.original?.hours ?? '';
  }

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  @override
  void dispose() {
    _description.dispose();
    _dateText.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final first = DateTime(widget.year, widget.month, 1);
    final last = DateTime(widget.year, widget.month + 1, 0);
    final initial =
        _date != null && !_date!.isBefore(first) && !_date!.isAfter(last)
            ? _date!
            : first;
    final selected = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        helpText: 'Дата замены в месяце отчёта');
    if (selected != null && mounted) {
      setState(() {
        _date = selected;
        _dateText.text = _displayDate(selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(
              widget.original == null ? 'Добавить замену' : 'Изменить замену'),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                                controller: _dateText,
                                readOnly: true,
                                onTap: _chooseDate,
                                decoration: const InputDecoration(
                                    labelText: 'Дата замены',
                                    helperText:
                                        'Только в пределах месяца отчёта',
                                    suffixIcon:
                                        Icon(Icons.calendar_month_outlined)),
                                validator: (_) => _date == null
                                    ? 'Выберите дату'
                                    : _date!.year != widget.year ||
                                            _date!.month != widget.month
                                        ? 'Дата должна быть в месяце отчёта'
                                        : null),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _description,
                                maxLength: 500,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                    labelText: 'Кого и в какой группе заменяли',
                                    hintText:
                                        'Например: Иванова И.И., группа ПР-21'),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Укажите описание замены'
                                        : null),
                            const SizedBox(height: 12),
                            HoursInputField(
                                label: 'Часы замены',
                                value: _hours,
                                onChanged: (value) => _hours = value),
                            const SizedBox(height: 8),
                            const Text(
                                'Замены учитываются отдельно от годового плана назначений.'),
                          ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  final date =
                      '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}';
                  Navigator.pop(
                      context,
                      EditableSubstitution(
                          id: widget.original?.id,
                          key: widget.original?.key,
                          date: date,
                          description: _description.text.trim(),
                          hours: DecimalInput.tryParse(_hours)!.canonical));
                },
                child: const Text('Сохранить замену'))
          ]);
}
