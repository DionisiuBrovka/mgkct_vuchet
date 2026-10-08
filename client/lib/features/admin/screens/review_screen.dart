import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain.dart';
import '../../../shared/widgets/assignment_progress.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/screen_hint.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen(
      {super.key,
      required this.teacher,
      required this.month,
      required this.year});
  final String teacher, month;
  final int year;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => context
      .read<AdminCubit>()
      .loadTeacherEntries(widget.teacher, widget.month, widget.year);
  Future<void> _confirm() async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Подтвердить отчёт?'),
                content: const Text(
                    'Часы будут включены в подтверждённое выполнение годового плана. После подтверждения изменить отчёт нельзя.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Подтвердить'))
                ]));
    if (accepted == true && mounted) await context.read<AdminCubit>().confirm();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('${widget.month} ${widget.year}')),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: BlocBuilder<AdminCubit, AdminState>(
                  builder: (context, state) {
                if (state is AdminLoading || state is AdminInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AdminError) {
                  return Center(
                      child: TextButton(
                          onPressed: _reload,
                          child: Text('Повторить: ${state.message}')));
                }
                final loaded = state as AdminReviewLoaded;
                final report = loaded.report;
                return ListView(padding: const EdgeInsets.all(20), children: [
                  Text(
                      report.teacher.name.isEmpty
                          ? 'Отчёт преподавателя'
                          : report.teacher.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(report.status)),
                  ScreenHint(
                      title: report.status == ReportStatus.submitted
                          ? 'Проверьте часы и годовой план'
                          : 'Результат проверки',
                      message: report.status == ReportStatus.submitted
                          ? 'Сверьте нагрузку и замены. Превышение плана — предупреждение; при необходимости верните отчёт преподавателю.'
                          : report.status == ReportStatus.confirmed
                              ? 'Отчёт подтверждён. Часы учтены в выполнении плана, изменение недоступно.'
                              : 'Отчёт возвращён на доработку. Преподаватель сможет исправить и отправить его снова.'),
                  if (loaded.error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loaded.error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                              TextButton(
                                  onPressed: loaded.isUpdating ? null : _reload,
                                  child: const Text('Обновить отчёт'))
                            ])),
                  for (final entry in report.entries)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${entry.assignment.subject} · ${entry.assignment.group}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 16),
                                  Wrap(spacing: 16, runSpacing: 12, children: [
                                    for (final item in entry.hours.entries)
                                      SizedBox(
                                          width: 230,
                                          child: Text(
                                              '${_hourName(item.key)}: ${item.value} ч',
                                              style: TextStyle(
                                                  color: item.value.value == '0'
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                      : null)))
                                  ]),
                                  const Divider(height: 32),
                                  Text('Итого за месяц: ${entry.total} ч',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  if (entry.assignment.progress != null)
                                    AssignmentProgressView(
                                        progress: entry.assignment.progress!,
                                        academicYear: report.month >= 9
                                            ? report.year
                                            : report.year - 1),
                                ]))),
                  const SizedBox(height: 20),
                  Text('Замены · ${report.substitutions.length}',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (report.substitutions.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Замены не указаны.')),
                  for (final item in report.substitutions)
                    Card(
                        child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            title: Text(item.description),
                            subtitle: Text('${item.date} · ${item.hours} ч'))),
                  Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Всего за месяц: ${report.totals['grandTotal']} ч',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                Text(
                                    'По назначениям: ${report.totals['assignmentTotal']} ч · Замены: ${report.totals['substitutionTotal']} ч'),
                              ]))),
                  if (report.status == ReportStatus.submitted)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Wrap(spacing: 12, runSpacing: 12, children: [
                          OutlinedButton.icon(
                              onPressed: loaded.isUpdating
                                  ? null
                                  : () => context.read<AdminCubit>().reject(),
                              icon: const Icon(Icons.undo),
                              label: const Text('Вернуть на доработку')),
                          FilledButton.icon(
                              onPressed: loaded.isUpdating ? null : _confirm,
                              icon: const Icon(Icons.check),
                              label: Text(loaded.isUpdating
                                  ? 'Сохраняем…'
                                  : 'Подтвердить отчёт')),
                        ])),
                ]);
              }))));
}

String _hourName(String key) =>
    const {
      'lectureHours': 'Лекции',
      'practicalHours': 'Лабораторные и практические',
      'courseProjectHours': 'Курсовые проекты',
      'consultationHours': 'Консультации',
      'additionalAssessmentHours': 'Допконтроль',
      'examHours': 'Экзамены',
    }[key] ??
    key;
