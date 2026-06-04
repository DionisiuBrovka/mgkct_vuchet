import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/hours_input_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../cubit/vychitka_cubit.dart';
import '../cubit/vychitka_state.dart';
import '../models/vychitka_entry.dart';
import '../models/zamena.dart';

class FillVychitkaScreen extends StatefulWidget {
  const FillVychitkaScreen({
    super.key,
    required this.month,
    required this.year,
  });

  final String month;
  final int year;

  @override
  State<FillVychitkaScreen> createState() => _FillVychitkaScreenState();
}

class _FillVychitkaScreenState extends State<FillVychitkaScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _teacher;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state as AuthAuthenticated;
    _teacher = auth.user.name;
    context
        .read<VychitkaCubit>()
        .loadMonth(_teacher, widget.month, widget.year);
  }

  Future<void> _showAddZamenaDialog(BuildContext ctx) async {
    final groupCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Добавить замену'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: groupCtrl,
                decoration: const InputDecoration(labelText: 'Группа'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Обязательно' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: dateCtrl,
                decoration:
                    const InputDecoration(labelText: 'Дата (ДД.ММ.ГГГГ)'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Обязательно' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: hoursCtrl,
                decoration:
                    const InputDecoration(labelText: 'Часы'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (v == null || double.tryParse(v) == null)
                        ? 'Введите число'
                        : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                ctx.read<VychitkaCubit>().addZamena(Zamena(
                      teacher: _teacher,
                      month: widget.month,
                      year: widget.year,
                      group: groupCtrl.text.trim(),
                      date: dateCtrl.text.trim(),
                      hours: double.parse(hoursCtrl.text),
                    ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.month} ${widget.year}'),
      ),
      body: BlocConsumer<VychitkaCubit, VychitkaState>(
        listener: (ctx, state) {
          if (state is VychitkaError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (ctx, state) {
          if (state is VychitkaLoading || state is VychitkaInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is VychitkaError) {
            return Center(child: Text(state.message));
          }
          final loaded = state as VychitkaLoaded;
          final locked = loaded.entries.isNotEmpty &&
              loaded.entries.first.status != VychitkaStatus.draft;

          return Form(
            key: _formKey,
            child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Text('Статус: '),
                          StatusBadge(loaded.entries.first.status),
                        ],
                      ),
                    ),
                  ...loaded.entries.map((e) => _EntryCard(
                        entry: e,
                        locked: locked,
                        onChanged: (updated) =>
                            ctx.read<VychitkaCubit>().updateEntry(updated),
                      )),
                  const SizedBox(height: 16),
                  _ZamenySection(
                    zameny: loaded.zameny,
                    locked: locked,
                    onAdd: () => _showAddZamenaDialog(ctx),
                    onDelete: (z) =>
                        ctx.read<VychitkaCubit>().deleteZamena(z),
                  ),
                ],
              ),
              if (!locked)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: loaded.isSaving
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    ctx.read<VychitkaCubit>().saveDraft();
                                  }
                                },
                          child: loaded.isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Text('Сохранить черновик'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: loaded.isSaving
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  final cubit = ctx.read<VychitkaCubit>();
                                  final ok = await _confirmSubmitDialog(ctx);
                                  if (ok == true) {
                                    cubit.submit();
                                  }
                                },
                          child: const Text('Отправить →'),
                        ),
                      ),
                    ],
                  ),
                ),
              if (loaded.isSaving)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x44000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ));
        },
      ),
    );
  }

  Future<bool?> _confirmSubmitDialog(BuildContext ctx) =>
      showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Отправить на проверку?'),
          content: const Text(
              'После отправки вычитка будет заблокирована до решения завуча.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Отправить')),
          ],
        ),
      );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.locked,
    required this.onChanged,
  });

  final VychitkaEntry entry;
  final bool locked;
  final ValueChanged<VychitkaEntry> onChanged;

  @override
  Widget build(BuildContext context) {
    final fields = [
      (label: 'Лек',    value: entry.lek,      set: (v) => entry.copyWith(lek: v)),
      (label: 'ЛР/ПР', value: entry.lrPr,     set: (v) => entry.copyWith(lrPr: v)),
      (label: 'КП',     value: entry.kp,       set: (v) => entry.copyWith(kp: v)),
      (label: 'Конс',   value: entry.cons,     set: (v) => entry.copyWith(cons: v)),
      (label: 'Доп.к',  value: entry.dopKontr, set: (v) => entry.copyWith(dopKontr: v)),
      (label: 'Экз',    value: entry.ekz,      set: (v) => entry.copyWith(ekz: v)),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.subject} · гр. ${entry.group}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            // все 6 полей в один ряд
            Row(
              children: [
                for (int i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: HoursInputField(
                      label: fields[i].label,
                      value: fields[i].value,
                      enabled: !locked,
                      onChanged: (v) => onChanged(fields[i].set(v)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZamenySection extends StatelessWidget {
  const _ZamenySection({
    required this.zameny,
    required this.locked,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Zamena> zameny;
  final bool locked;
  final VoidCallback onAdd;
  final ValueChanged<Zamena> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Замены',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const Spacer(),
            if (!locked)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить'),
              ),
          ],
        ),
        if (zameny.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Нет замен', style: TextStyle(color: Colors.grey)),
          )
        else
          ...zameny.map((z) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Гр. ${z.group} — ${z.date}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${z.hours} ч'),
                    if (!locked)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => onDelete(z),
                      ),
                  ],
                ),
              )),
      ],
    );
  }
}
