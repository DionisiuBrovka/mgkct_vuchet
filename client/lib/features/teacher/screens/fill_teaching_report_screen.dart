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
import 'substitution_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/assignment_heading.dart';
import '../../../shared/widgets/screen_hint.dart';

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
  int _section = 0;
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
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: BlocConsumer<TeachingReportCubit, TeachingReportState>(
                    listenWhen: (previous, current) =>
                        previous is TeachingReportLoaded &&
                        previous.isSaving &&
                        current is TeachingReportLoaded &&
                        !current.isSaving &&
                        current.error == null,
                    listener: (context, state) {
                      final report =
                          (state as TeachingReportLoaded).editor.report;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(report.status == ReportStatus.draft
                              ? 'Черновик сохранён'
                              : 'Отчёт отправлен на проверку')));
                    },
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
                                    .loadMonth(
                                        _teacher, widget.year, widget.month),
                                child: Text('Повторить: ${state.message}')));
                      }
                      final loaded = state as TeachingReportLoaded;
                      final report = loaded.editor.report;
                      final locked = report.status != ReportStatus.draft;
                      return Form(
                          key: _form,
                          child: Stack(children: [
                            Column(children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                child: DefaultTabController(
                                  length: 2,
                                  child: TabBar(
                                    onTap: (index) {
                                      FocusScope.of(context).unfocus();
                                      setState(() => _section = index);
                                    },
                                    tabs: [
                                      Tab(
                                          text:
                                              'Назначения (${report.entries.length})'),
                                      Tab(
                                          text:
                                              'Замены (${loaded.editor.substitutions.length})'),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                  child:
                                      IndexedStack(index: _section, children: [
                                ListView(
                                    key: const PageStorageKey('assignments'),
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 12, 20, 180),
                                    children: [
                                      Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            StatusBadge(report.status),
                                            Text(
                                                'Назначений: ${report.entries.length} · Замен: ${loaded.editor.substitutions.length}'),
                                          ]),
                                      const SizedBox(height: 16),
                                      ScreenHint(
                                          title: locked
                                              ? 'Отчёт отправлен'
                                              : 'Заполните часы за месяц',
                                          message: locked
                                              ? 'Изменения недоступны. Годовой план и итоги можно просматривать.'
                                              : 'Пустое поле — 0. Дробные часы вводите через запятую или точку. Основные часы и допконтроль сравниваются с планом отдельно; превышение не мешает отправке.'),
                                      if (loaded.error != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Text(loaded.error!,
                                                      style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .error))),
                                              TextButton(
                                                  onPressed: () => context
                                                      .read<
                                                          TeachingReportCubit>()
                                                      .loadMonth(
                                                          _teacher,
                                                          widget.year,
                                                          widget.month),
                                                  child: const Text(
                                                      'Открыть актуальный')),
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
                                            locked: locked || loaded.isSaving),
                                    ]),
                                ListView(
                                  key: const PageStorageKey('substitutions'),
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 12, 20, 180),
                                  children: [
                                    ScreenHint(
                                      title:
                                          'Замены за ${_monthName(widget.month).toLowerCase()}',
                                      message: locked
                                          ? 'Отчёт отправлен. Замены доступны только для просмотра.'
                                          : 'Укажите дату, кого и в какой группе заменяли, и количество часов. Замены сохраняются и отправляются вместе с назначениями.',
                                    ),
                                    const SizedBox(height: 20),
                                    _SubstitutionsSection(
                                        items: loaded.editor.substitutions,
                                        locked: locked || loaded.isSaving,
                                        onEdit: (item) =>
                                            _editSubstitution(item),
                                        onDelete: (item) => context
                                            .read<TeachingReportCubit>()
                                            .deleteSubstitution(item)),
                                    const SizedBox(height: 16),
                                    Text(
                                        'Итого по заменам: ${loaded.editor.substitutionTotal.canonical} ч'),
                                  ],
                                ),
                              ])),
                            ]),
                            if (!locked)
                              Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                  child: SafeArea(
                                      child: Material(
                                          elevation: 4,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          child: Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (loaded.error != null &&
                                                        _section == 1)
                                                      Text(loaded.error!,
                                                          style: TextStyle(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .error)),
                                                    Text(
                                                        'Назначения: ${loaded.editor.assignmentTotal.canonical} ч · Замены: ${loaded.editor.substitutionTotal.canonical} ч · Всего: ${loaded.editor.grandTotal.canonical} ч',
                                                        textAlign:
                                                            TextAlign.center),
                                                    const SizedBox(height: 12),
                                                    Row(children: [
                                                      Expanded(
                                                          child: FilledButton
                                                              .tonal(
                                                                  onPressed: loaded
                                                                          .isSaving
                                                                      ? null
                                                                      : () {
                                                                          if (_validate()) {
                                                                            context.read<TeachingReportCubit>().saveDraft();
                                                                          }
                                                                        },
                                                                  child: Text(
                                                                      loaded.isSaving
                                                                          ? 'Сохраняем…'
                                                                          : 'Сохранить черновик',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center))),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                          child: FilledButton(
                                                              onPressed: loaded
                                                                      .isSaving
                                                                  ? null
                                                                  : () {
                                                                      if (_validate()) {
                                                                        context
                                                                            .read<TeachingReportCubit>()
                                                                            .submit();
                                                                      }
                                                                    },
                                                              child: const Text(
                                                                  'Отправить'))),
                                                    ]),
                                                  ]))))),
                          ]));
                    }))),
      );

  bool _validate() {
    final valid = _form.currentState!.validate();
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Проверьте поля часов на вкладке «Назначения».'),
      ));
    }
    return valid;
  }

  Future<void> _editSubstitution(EditableSubstitution? original) async {
    final result = await showDialog<EditableSubstitution>(
        context: context,
        builder: (_) => SubstitutionDialog(
            year: widget.year, month: widget.month, original: original));
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
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AssignmentHeading(
                subject: entry.assignment.subject,
                group: entry.assignment.group),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 960
                  ? 6
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              return Wrap(spacing: 16, runSpacing: 20, children: [
                for (final field in [
                  ...hourKeys
                      .where((key) => key != 'additionalAssessmentHours'),
                  'additionalAssessmentHours',
                ])
                  SizedBox(
                      width: width,
                      child: HoursInputField(
                          label: _label(field),
                          value: editor.value(entry.assignment.id, field),
                          enabled: !locked,
                          onChanged: (value) => context
                              .read<TeachingReportCubit>()
                              .updateValue(entry.assignment.id, field, value)))
              ]);
            }),
            const SizedBox(height: 16),
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
      'lectureHours': 'Лекции',
      'practicalHours': 'Лаб. и практические',
      'courseProjectHours': 'Курсовые проекты',
      'consultationHours': 'Консультации',
      'additionalAssessmentHours': 'Допконтроль',
      'examHours': 'Экзамены'
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
        Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Замены', style: Theme.of(context).textTheme.titleLarge),
              if (!locked)
                TextButton.icon(
                    onPressed: () => onEdit(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить замену'))
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
                          tooltip: 'Изменить замену',
                          icon: const Icon(Icons.edit)),
                      IconButton(
                          onPressed: () => onDelete(item),
                          tooltip: 'Удалить замену',
                          icon: const Icon(Icons.delete_outline))
                    ])),
        if (items.isEmpty)
          const Card(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Пока нет замен. Если в этом месяце вы заменяли другого преподавателя, добавьте запись.'),
          )),
      ]);
}
