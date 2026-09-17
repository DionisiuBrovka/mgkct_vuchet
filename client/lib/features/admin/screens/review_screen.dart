// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain.dart';
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
    context
        .read<AdminCubit>()
        .loadTeacherEntries(widget.teacher, widget.month, widget.year);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('${widget.month} ${widget.year}')),
      body: BlocBuilder<AdminCubit, AdminState>(builder: (_, state) {
        if (state is AdminLoading || state is AdminInitial)
          return const Center(child: CircularProgressIndicator());
        if (state is AdminError) return Center(child: Text(state.message));
        final report = (state as AdminReviewLoaded).report;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(
              report.teacher.name.isEmpty
                  ? widget.teacher
                  : report.teacher.name,
              style: Theme.of(context).textTheme.titleLarge),
          Text('Статус: ${report.status.name}'),
          const SizedBox(height: 12),
          for (final entry in report.entries)
            Card(
                child: ListTile(
                    title: Text(
                        '${entry.assignment.subject} · ${entry.assignment.group}'),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in entry.hours.entries)
                            Text(
                                '${_hourName(item.key)}: ${item.value.value} ч',
                                style: TextStyle(
                                    color: item.value.value == '0'
                                        ? Theme.of(context).disabledColor
                                        : null)),
                          Text('Итого: ${entry.total.value} ч'),
                        ]))),
          const SizedBox(height: 12),
          Text('Итого назначений: ${report.totals['assignmentTotal']} ч'),
          Text('Итого замен: ${report.totals['substitutionTotal']} ч'),
          Text('Всего: ${report.totals['grandTotal']} ч'),
          for (final item in report.substitutions)
            ListTile(
                title: Text(item.description),
                subtitle: Text('${item.date} · ${item.hours} ч')),
          if (report.status == ReportStatus.submitted)
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: state.isUpdating
                          ? null
                          : () => context.read<AdminCubit>().reject(),
                      child: const Text('Вернуть'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: state.isUpdating
                          ? null
                          : () => context.read<AdminCubit>().confirm(),
                      child: const Text('Подтвердить')))
            ])
        ]);
      }));
}

String _hourName(String key) =>
    const {
      'lectureHours': 'Лекции',
      'practicalHours': 'ЛР/ПР',
      'courseProjectHours': 'Курсовые проекты',
      'consultationHours': 'Консультации',
      'additionalAssessmentHours': 'Дополнительный контроль',
      'examHours': 'Экзамены',
    }[key] ??
    key;
