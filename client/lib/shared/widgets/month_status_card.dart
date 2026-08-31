import 'package:flutter/material.dart';

import '../../features/teacher/models/teaching_report_entry.dart';
import 'status_badge.dart';

class MonthStatusCard extends StatelessWidget {
  const MonthStatusCard({
    super.key,
    required this.month,
    required this.year,
    required this.status,
    this.onTap,
  });

  final String month;
  final int year;
  final TeachingReportStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      child: ListTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(12)),
        title: Text('$month $year',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(status == TeachingReportStatus.draft
            ? 'Открыть и заполнить часы'
            : 'Открыть для просмотра'),
        trailing: StatusBadge(status),
        onTap: onTap,
      ),
    );
  }
}
