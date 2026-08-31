import 'package:flutter/material.dart';

import '../../features/teacher/models/teaching_report_entry.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final TeachingReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TeachingReportStatus.draft => ('Черновик', Colors.grey),
      TeachingReportStatus.submitted => ('На проверке', Colors.orange),
      TeachingReportStatus.confirmed => ('Подтверждена', Colors.green),
    };
    final description = switch (status) {
      TeachingReportStatus.draft =>
        'Преподаватель может редактировать отчёт. Завучу он ещё не отправлен.',
      TeachingReportStatus.submitted =>
        'Отчёт отправлен завучу. Редактирование недоступно до возврата на доработку.',
      TeachingReportStatus.confirmed =>
        'Завуч принял отчёт. Доступен только просмотр.',
    };
    return Tooltip(
      message: description,
      child: Chip(
        label:
            Text(label, style: TextStyle(color: color.shade800, fontSize: 12)),
        backgroundColor: color.shade100,
        side: BorderSide(color: color.shade300),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
