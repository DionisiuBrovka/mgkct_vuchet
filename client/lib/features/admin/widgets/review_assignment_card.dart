import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/hour_descriptions.dart';
import '../../teacher/models/teaching_report_entry.dart';

String formatReviewHours(num value) =>
    NumberFormat('0.##########', 'ru').format(value);

class ReviewAssignmentCard extends StatelessWidget {
  const ReviewAssignmentCard({super.key, required this.entry});

  final TeachingReportEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(entry.subject,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Группа ${entry.group}',
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('Всего ${formatReviewHours(entry.totalHours)} ч',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ReviewHoursBreakdown(values: {
              'Лек': entry.lectureHours,
              'ЛР/ПР': entry.practicalHours,
              'КП': entry.courseProjectHours,
              'Конс': entry.consultationHours,
              'Доп.к': entry.additionalAssessmentHours,
              'Экз': entry.examHours,
            }),
          ],
        ),
      ),
    );
  }
}

class ReviewHoursBreakdown extends StatelessWidget {
  const ReviewHoursBreakdown({super.key, required this.values});

  final Map<String, num> values;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final scaledWidth =
          constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1);
      final columns = scaledWidth >= 850
          ? 6
          : scaledWidth >= 480
              ? 3
              : 2;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final field in values.entries)
            SizedBox(
              width: width,
              child: Container(
                constraints: const BoxConstraints(minHeight: 76),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: field.value == 0
                      ? colors.surfaceContainerLow
                      : colors.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatReviewHours(field.value)} ч',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: field.value == 0
                                ? colors.onSurfaceVariant
                                : colors.primary)),
                    const SizedBox(height: 3),
                    Text(hourDescriptions[field.key] ?? field.key,
                        style: TextStyle(
                            fontSize: 12, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}
