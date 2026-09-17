import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain.dart';
import '../../../shared/widgets/hours_input_field.dart';
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
                      Text(
                          'Замены: ${report.substitutions.isEmpty ? 'не указаны' : report.substitutions.map((s) => '${s.description} — ${s.hours.value} ч').join('; ')}'),
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
            Text('Итого: ${editor.totalFor(entry).canonical} ч'),
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
