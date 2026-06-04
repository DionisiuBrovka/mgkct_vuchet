import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/vychitka_cubit.dart';
import '../cubit/vychitka_state.dart';
import '../models/vychitka_entry.dart';

class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({super.key, required this.month, required this.year});

  final String month;
  final int year;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<VychitkaCubit>().state;
    if (state is! VychitkaLoaded) {
      return Scaffold(
        appBar: AppBar(title: Text('$month $year')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final entries = state.entries;
    final zameny = state.zameny;

    final totals = <String, double>{
      'Лек': entries.fold(0, (s, e) => s + e.lek),
      'ЛР/ПР': entries.fold(0, (s, e) => s + e.lrPr),
      'КП': entries.fold(0, (s, e) => s + e.kp),
      'Конс': entries.fold(0, (s, e) => s + e.cons),
      'Доп.к': entries.fold(0, (s, e) => s + e.dopKontr),
      'Экз': entries.fold(0, (s, e) => s + e.ekz),
    };

    return Scaffold(
      appBar: AppBar(title: Text('Итог: $month $year')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Часы по назначениям',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...entries.map((e) => _EntryRow(e)),
          const Divider(height: 32),
          const Text('Итого по видам нагрузки',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: totals.keys
                    .map((k) => _tableCell(k, bold: true))
                    .toList(),
              ),
              TableRow(
                children: totals.values
                    .map((v) => _tableCell(v.toString()))
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (zameny.isNotEmpty) ...[
            const Text('Замены',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...zameny.map((z) => Text('${z.date} · гр. ${z.group} · ${z.hours} ч')),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('← Назад'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: state.isSaving
                      ? null
                      : () => context.read<VychitkaCubit>().submit(),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('✓ Подтвердить и отправить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow(this.entry);
  final VychitkaEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
                '${entry.subject} · гр. ${entry.group}'),
          ),
          Text('${entry.totalHours} ч',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
