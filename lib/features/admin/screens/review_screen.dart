import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/status_badge.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../teacher/models/vychitka_entry.dart';
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
    final adminName =
        (context.read<AuthCubit>().state as AuthAuthenticated).user.name;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.teacher}\n${widget.month} ${widget.year}',
            maxLines: 2,
            style: const TextStyle(fontSize: 14)),
      ),
      body: BlocConsumer<AdminCubit, AdminState>(
        listener: (ctx, state) {
          if (state is AdminError) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is AdminReviewLoaded && !state.isUpdating) {
            // After confirm/reject navigate back
            final entries = state.entries;
            if (entries.isNotEmpty &&
                entries.first.status != VychitkaStatus.submitted) {
              Navigator.of(ctx).pop(true);
            }
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
          final entries = loaded.entries;
          final zameny = loaded.zameny;

          final totals = <String, double>{
            'Лек': entries.fold(0, (s, e) => s + e.lek),
            'ЛР/ПР': entries.fold(0, (s, e) => s + e.lrPr),
            'КП': entries.fold(0, (s, e) => s + e.kp),
            'Конс': entries.fold(0, (s, e) => s + e.cons),
            'Доп.к': entries.fold(0, (s, e) => s + e.dopKontr),
            'Экз': entries.fold(0, (s, e) => s + e.ekz),
          };

          final currentStatus =
              entries.isNotEmpty ? entries.first.status : VychitkaStatus.draft;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  Row(children: [
                    const Text('Статус: '),
                    StatusBadge(currentStatus),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Назначения',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '${e.subject} · гр. ${e.group}')),
                          Text('${e.totalHours} ч',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      )),
                  const Divider(height: 32),
                  const Text('Итого',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      TableRow(
                        decoration:
                            BoxDecoration(color: Colors.grey.shade100),
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
                  if (zameny.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Замены',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...zameny.map((z) =>
                        Text('${z.date} · гр. ${z.group} · ${z.hours} ч')),
                  ],
                ],
              ),
              if (currentStatus == VychitkaStatus.submitted)
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
                              : () => context
                                  .read<AdminCubit>()
                                  .reject(widget.teacher, widget.month,
                                      widget.year),
                          child: const Text('↩ Вернуть'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: loaded.isUpdating
                              ? null
                              : () => context.read<AdminCubit>().confirm(
                                    widget.teacher,
                                    widget.month,
                                    widget.year,
                                    adminName,
                                  ),
                          child: loaded.isUpdating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
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
