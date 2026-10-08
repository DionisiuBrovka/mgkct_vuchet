import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain.dart';
import '../../../shared/widgets/hours_input_field.dart';
import '../../../shared/widgets/assignment_progress.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../cubit/teaching_report_cubit.dart';
import '../cubit/teaching_report_state.dart';
import '../models/editable_report.dart';

class FillTeachingReportScreen extends StatefulWidget {
  const FillTeachingReportScreen(
      {super.key, required this.month, required this.year});
  final int month, year;
  @override
  State<FillTeachingReportScreen> createState() =>
      _FillTeachingReportScreenState();
}

class _FillTeachingReportScreenState extends State<FillTeachingReportScreen> {
  final _form = GlobalKey<FormState>();
  late final String _teacher;
  @override
  void initState() {
    super.initState();
    _teacher = (context.read<AuthCubit>().state as AuthAuthenticated).user.id;
    context
        .read<TeachingReportCubit>()
        .loadMonth(_teacher, widget.year, widget.month);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text('${_monthName(widget.month)} ${widget.year}')),
        body: BlocBuilder<TeachingReportCubit, TeachingReportState>(
            builder: (context, state) {
          if (state is TeachingReportInitial ||
              state is TeachingReportLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TeachingReportError) {
            return Center(
                child: TextButton(
                    onPressed: () => context
                        .read<TeachingReportCubit>()
                        .loadMonth(_teacher, widget.year, widget.month),
                    child: Text('Повторить: ${state.message}')));
          }
          final loaded = state as TeachingReportLoaded;
          final report = loaded.editor.report;
          final locked = report.status != ReportStatus.draft;
          return Form(
              key: _form,
              child: Stack(children: [
                ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Text(locked
                          ? 'Отчёт доступен только для просмотра.'
                          : 'Пустое поле означает 0. Допустимы точные дроби через запятую или точку.'),
                      if (loaded.error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(children: [
                              Expanded(
                                  child: Text(loaded.error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                              TextButton(
                                  onPressed: () => context
                                      .read<TeachingReportCubit>()
                                      .loadMonth(
                                          _teacher, widget.year, widget.month),
                                  child: const Text('Открыть актуальный')),
                            ])),
                      if (report.entries.isEmpty)
                        const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                                'Назначений нет. Обратитесь к администратору; замены можно будет добавить отдельно.')),
                      for (final entry in report.entries)
                        _EntryCard(
                            editor: loaded.editor,
                            entry: entry,
                            locked: locked),
                      const SizedBox(height: 12),
                      _SubstitutionsSection(
                          items: loaded.editor.substitutions,
                          locked: locked,
                          onEdit: (item) => _editSubstitution(item),
                          onDelete: (item) => context
                              .read<TeachingReportCubit>()
                              .deleteSubstitution(item)),
                      Text(
                          'Итого по назначениям: ${loaded.editor.assignmentTotal.canonical} ч; общий итог: ${loaded.editor.grandTotal.canonical} ч'),
                    ]),
                if (!locked)
                  Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Row(children: [
                        Expanded(
                            child: FilledButton.tonal(
                                onPressed: loaded.isSaving
                                    ? null
                                    : () {
                                        if (_form.currentState!.validate()) {
                                          context
                                              .read<TeachingReportCubit>()
                                              .saveDraft();
                                        }
                                      },
                                child: const Text('Сохранить черновик'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: FilledButton(
                                onPressed: loaded.isSaving
                                    ? null
                                    : () {
                                        if (_form.currentState!.validate()) {
                                          context
                                              .read<TeachingReportCubit>()
                                              .submit();
                                        }
                                      },
                                child: const Text('Отправить'))),
                      ])),
              ]));
        }),
      );

  Future<void> _editSubstitution(EditableSubstitution? original) async {
    final item = original?.copy() ??
        EditableSubstitution(date: '', description: '', hours: '');
    final date = TextEditingController(text: item.date);
    final description = TextEditingController(text: item.description);
    final hours = TextEditingController(text: item.hours);
    final result = await showDialog<EditableSubstitution>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(
                  original == null ? 'Добавить замену' : 'Изменить замену'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: date,
                    decoration:
                        const InputDecoration(labelText: 'Дата (ГГГГ-ММ-ДД)')),
                TextField(
                    controller: description,
                    decoration: const InputDecoration(
                        labelText: 'Кого и в какой группе заменяли')),
                TextField(
                    controller: hours,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Часы')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () => Navigator.pop(
                        context,
                        EditableSubstitution(
                            id: item.id,
                            key: item.key,
                            date: date.text.trim(),
                            description: description.text.trim(),
                            hours: hours.text.trim())),
                    child: const Text('Сохранить')),
              ],
            ));
    date.dispose();
    description.dispose();
    hours.dispose();
    if (result != null && mounted) {
      context.read<TeachingReportCubit>().saveSubstitution(result);
    }
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard(
      {required this.editor, required this.entry, required this.locked});
  final EditableReport editor;
  final EntryDto entry;
  final bool locked;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${entry.assignment.subject} · гр. ${entry.assignment.group}'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final field in hourKeys)
                SizedBox(
                    width: 95,
                    child: HoursInputField(
                        label: _label(field),
                        value: editor.value(entry.assignment.id, field),
                        enabled: !locked,
                        onChanged: (value) => context
                            .read<TeachingReportCubit>()
                            .updateValue(entry.assignment.id, field, value)))
            ]),
            Text('Итого за месяц: ${editor.totalFor(entry).canonical} ч'),
            if (entry.assignment.progress != null)
              AssignmentProgressView(
                  progress: entry.assignment.progress!,
                  academicYear: editor.report.month >= 9
                      ? editor.report.year
                      : editor.report.year - 1,
                  currentMain: editor.categoryFor(entry, additional: false),
                  currentAdditional:
                      editor.categoryFor(entry, additional: true),
                  editing: !locked),
          ])));
}

String _monthName(int month) =>
    const {
      1: 'Январь',
      2: 'Февраль',
      3: 'Март',
      4: 'Апрель',
      5: 'Май',
      6: 'Июнь',
      7: 'Июль',
      9: 'Сентябрь',
      10: 'Октябрь',
      11: 'Ноябрь',
      12: 'Декабрь'
    }[month] ??
    '$month';
String _label(String key) => const {
      'lectureHours': 'Лек',
      'practicalHours': 'ЛР/ПР',
      'courseProjectHours': 'КП',
      'consultationHours': 'Конс',
      'additionalAssessmentHours': 'Доп.к',
      'examHours': 'Экз'
    }[key]!;

class _SubstitutionsSection extends StatelessWidget {
  const _SubstitutionsSection(
      {required this.items,
      required this.locked,
      required this.onEdit,
      required this.onDelete});
  final List<EditableSubstitution> items;
  final bool locked;
  final ValueChanged<EditableSubstitution?> onEdit;
  final ValueChanged<EditableSubstitution> onDelete;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Замены'),
          const Spacer(),
          if (!locked)
            TextButton.icon(
                onPressed: () => onEdit(null),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'))
        ]),
        for (final item in items)
          ListTile(
              title: Text(item.description),
              subtitle: Text('${item.date} · ${item.hours} ч'),
              trailing: locked
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          onPressed: () => onEdit(item),
                          icon: const Icon(Icons.edit)),
                      IconButton(
                          onPressed: () => onDelete(item),
                          icon: const Icon(Icons.delete_outline))
                    ])),
        if (items.isEmpty) const Text('Замены не указаны.'),
      ]);
}
