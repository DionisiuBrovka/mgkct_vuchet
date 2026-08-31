import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/status_badge.dart';
import '../../teacher/models/teaching_report_entry.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.teacher,
    required this.month,
    required this.year,
  });

  final String teacher;
  final String month;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.month} ${widget.year}',
            maxLines: 2, style: const TextStyle(fontSize: 14)),
      ),
      body: BlocConsumer<AdminCubit, AdminState>(
        listener: (ctx, state) {
          if (state is AdminError) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is AdminReviewLoaded && state.error != null) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(state.error!)));
          }
          if (state is AdminReviewLoaded && state.completed) {
            Navigator.of(ctx).pop(true);
          }
        },
        builder: (_, state) {
          if (state is AdminLoading || state is AdminInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminError) {
            return Center(child: Text(state.message));
          }
          final loaded = state as AdminReviewLoaded;
          final entries = loaded.report.entries;
          final substitutions = loaded.report.substitutions;

          final totals = <String, num>{
            'Лек': loaded.report.totals['lectureHours']!,
            'ЛР/ПР': loaded.report.totals['practicalHours']!,
            'КП': loaded.report.totals['courseProjectHours']!,
            'Конс': loaded.report.totals['consultationHours']!,
            'Доп.к': loaded.report.totals['additionalAssessmentHours']!,
            'Экз': loaded.report.totals['examHours']!,
          };
          final currentStatus = loaded.report.status;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  Text(loaded.report.teacherName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(children: [
                    const Text('Статус: '),
                    StatusBadge(currentStatus),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Назначения',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '${e.subject} · гр. ${e.group}\nЛек: ${e.lectureHours}; ЛР/ПР: ${e.practicalHours}; КП: ${e.courseProjectHours}\nКонс: ${e.consultationHours}; Доп.к: ${e.additionalAssessmentHours}; Экз: ${e.examHours}')),
                          Text('${e.totalHours} ч',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      )),
                  const Divider(height: 32),
                  const Text('Итого',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: totals.keys
                            .map((k) => _cell(k, bold: true))
                            .toList(),
                      ),
                      TableRow(
                        children: totals.values
                            .map((v) => _cell(v.toString()))
                            .toList(),
                      ),
                    ],
                  ),
                  if (substitutions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Замены',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...substitutions.map((substitution) => Text(
                        '${substitution.date} · гр. ${substitution.group} · ${substitution.hours} ч')),
                  ],
                ],
              ),
              if (currentStatus == TeachingReportStatus.submitted)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: loaded.isUpdating
                              ? null
                              : () => context.read<AdminCubit>().reject(),
                          child: const Text('↩ Вернуть'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: loaded.isUpdating
                              ? null
                              : () => context.read<AdminCubit>().confirm(),
                          child: loaded.isUpdating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('✓ Подтвердить'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}
