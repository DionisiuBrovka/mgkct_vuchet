import 'package:flutter/material.dart';
import '../../../shared/widgets/screen_hint.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/status_badge.dart';
import '../widgets/review_assignment_card.dart';
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

          return Center(
            child: SizedBox(
              width: 1100,
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      ScreenHint(
                        title: currentStatus == TeachingReportStatus.submitted
                            ? 'Проверьте часы и замены'
                            : 'Отчёт подтверждён',
                        message: currentStatus == TeachingReportStatus.submitted
                            ? 'Сверьте часы по назначениям и замены ниже. «Вернуть» снова откроет редактирование преподавателю. «Подтвердить» окончательно примет отчёт — изменить его через приложение будет нельзя.'
                            : 'Это принятый отчёт. Здесь можно посмотреть часы и замены, но изменить их или вернуть отчёт уже нельзя.',
                      ),
                      Text(loaded.report.teacherName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(children: [
                        const Text('Статус: '),
                        StatusBadge(currentStatus),
                      ]),
                      const SizedBox(height: 10),
                      Text('Назначения · ${entries.length}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          'Часы по каждому предмету и группе. Заполненные виды нагрузки выделены цветом.',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 10),
                      if (entries.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                                'Назначений в отчёте нет. Проверьте замены ниже.')),
                      ...entries
                          .map((entry) => ReviewAssignmentCard(entry: entry)),
                      const SizedBox(height: 8),
                      Card.filled(
                        color: const Color.fromARGB(255, 156, 216, 171),
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Итого по назначениям',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                  '${formatReviewHours(totals.values.fold<num>(0, (sum, hours) => sum + hours))} ч · без учёта замен',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              const SizedBox(height: 10),
                              ReviewHoursBreakdown(values: totals),
                            ],
                          ),
                        ),
                      ),
                      if (substitutions.isEmpty)
                        const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Text('Замены за этот месяц не указаны.')),
                      if (substitutions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                            'Замены · ${loaded.report.totals['substitutionHours'] ?? 0} ч',
                            style: const TextStyle(
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
              ),
            ),
          );
        },
      ),
    );
  }
}
