import 'package:flutter/material.dart';

import '../../core/decimal_input.dart';
import '../../core/domain.dart';

class AssignmentProgressView extends StatelessWidget {
  const AssignmentProgressView(
      {super.key,
      required this.progress,
      required this.academicYear,
      this.currentMain,
      this.currentAdditional,
      this.editing = false});
  final AssignmentProgress progress;
  final int academicYear;
  final DecimalInput? currentMain, currentAdditional;
  final bool editing;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('План на $academicYear–${academicYear + 1} учебный год',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 600
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final item in [
              ('Основные часы', progress.main, currentMain),
              ('Допконтроль', progress.additional, currentAdditional)
            ])
              Container(
                  width: width,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12)),
                  child: _category(context, item.$1, item.$2, item.$3)),
          ]);
        }),
      ]));

  Widget _category(BuildContext context, String title, PlanCategory category,
      DecimalInput? current) {
    final planned = category.planned;
    final projected = current == null
        ? null
        : DecimalInput.tryParse(category.otherReported.value)! + current;
    final over = planned != null &&
        (projected ??
                    (DecimalInput.tryParse(category.confirmed.value)! +
                        DecimalInput.tryParse(category.submitted.value)!))
                .compareTo(DecimalInput.tryParse(planned.value)!) >
            0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$title: ${planned == null ? 'план не задан' : 'план $planned ч'}',
          style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Text('Вычитано и подтверждено: ${category.confirmed} ч'),
      Text('На проверке: ${category.submitted} ч'),
      if (category.remaining != null)
        Text('Осталось по подтверждённым: ${category.remaining} ч'),
      if (category.excess != null && category.excess!.value != '0')
        Text('Превышение по подтверждённым: ${category.excess} ч',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (editing && projected != null)
        Text(
            'С учётом этого отчёта и часов на проверке: ${projected.canonical} ч',
            style: TextStyle(
                color: over ? Theme.of(context).colorScheme.error : null)),
      if (over)
        Text(
            editing
                ? 'План превышен. Отправка разрешена.'
                : 'План превышен с учётом часов на проверке.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600)),
    ]);
  }
}
