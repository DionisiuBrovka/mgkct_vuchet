import 'package:flutter/material.dart';

import '../../features/teacher/models/vychitka_entry.dart';
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
  final VychitkaStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('$month $year',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: StatusBadge(status),
        onTap: onTap,
      ),
    );
  }
}
