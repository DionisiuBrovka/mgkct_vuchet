import 'package:flutter/material.dart';

import '../../features/teacher/models/vychitka_entry.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final VychitkaStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      VychitkaStatus.draft => ('Черновик', Colors.grey),
      VychitkaStatus.submitted => ('На проверке', Colors.orange),
      VychitkaStatus.confirmed => ('Подтверждена', Colors.green),
    };
    return Chip(
      label: Text(label,
          style: TextStyle(color: color.shade800, fontSize: 12)),
      backgroundColor: color.shade100,
      side: BorderSide(color: color.shade300),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
