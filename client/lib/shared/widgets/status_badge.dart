import 'package:flutter/material.dart';

import '../../core/domain.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ReportStatus.draft => ('Черновик', Colors.grey),
      ReportStatus.submitted => ('На проверке', Colors.orange),
      ReportStatus.confirmed => ('Подтверждена', Colors.green),
    };
    final description = switch (status) {
      ReportStatus.draft =>
        'Преподаватель может редактировать отчёт. Завучу он ещё не отправлен.',
      ReportStatus.submitted =>
        'Отчёт отправлен завучу. Редактирование недоступно до возврата на доработку.',
      ReportStatus.confirmed => 'Завуч принял отчёт. Доступен только просмотр.',
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
