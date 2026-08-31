import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/hours_input_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../cubit/teaching_report_cubit.dart';
import '../cubit/teaching_report_state.dart';
import '../models/teaching_report_entry.dart';
import '../models/substitution.dart';

class FillTeachingReportScreen extends StatefulWidget {
  const FillTeachingReportScreen({
    super.key,
    required this.month,
    required this.year,
  });

  final String month;
  final int year;

  @override
  State<FillTeachingReportScreen> createState() =>
      _FillTeachingReportScreenState();
}

class _FillTeachingReportScreenState extends State<FillTeachingReportScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _teacher;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state as AuthAuthenticated;
    _teacher = auth.user.profileId;
    context
        .read<TeachingReportCubit>()
        .loadMonth(_teacher, widget.month, widget.year);
  }

  Future<void> _showAddSubstitutionDialog(BuildContext ctx) async {
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
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательно';
                  if (!RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(v)) {
                    return 'Формат ДД.ММ.ГГГГ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: hoursCtrl,
                decoration: const InputDecoration(labelText: 'Часы'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || double.tryParse(v) == null)
                    ? 'Введите число'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                ctx.read<TeachingReportCubit>().addSubstitution(Substitution(
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
      body: BlocConsumer<TeachingReportCubit, TeachingReportState>(
        listener: (ctx, state) {
          final error = state is TeachingReportError
              ? state.message
              : state is TeachingReportLoaded
                  ? state.error
                  : null;
          if (error != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
        builder: (ctx, state) {
          if (state is TeachingReportLoading ||
              state is TeachingReportInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TeachingReportError) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(state.message),
              TextButton(
                  onPressed: () => ctx
                      .read<TeachingReportCubit>()
                      .loadMonth(_teacher, widget.month, widget.year),
                  child: const Text('Повторить'))
            ]));
          }
          final loaded = state as TeachingReportLoaded;
          final locked = loaded.report.status != TeachingReportStatus.draft;

          return Form(
              key: _formKey,
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      if (loaded.error != null)
                        Text(loaded.error!,
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error)),
                      const Text(
                          'Часы и замены сохраняются вместе кнопкой «Сохранить черновик».'),
                      if (locked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Text('Статус: '),
                              StatusBadge(loaded.report.status),
                            ],
                          ),
                        ),
                      ...loaded.entries.map((e) => _EntryCard(
                            entry: e,
                            locked: locked,
                            onChanged: (updated) => ctx
                                .read<TeachingReportCubit>()
                                .updateEntry(updated),
                          )),
                      const SizedBox(height: 16),
                      _SubstitutionsSection(
                        substitutions: loaded.substitutions,
                        locked: locked,
                        onAdd: () => _showAddSubstitutionDialog(ctx),
                        onDelete: (substitution) => ctx
                            .read<TeachingReportCubit>()
                            .deleteSubstitution(substitution),
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
                                        ctx
                                            .read<TeachingReportCubit>()
                                            .saveDraft();
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
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      final cubit =
                                          ctx.read<TeachingReportCubit>();
                                      final ok =
                                          await _confirmSubmitDialog(ctx);
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

  Future<bool?> _confirmSubmitDialog(BuildContext ctx) => showDialog<bool>(
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

  final TeachingReportEntry entry;
  final bool locked;
  final ValueChanged<TeachingReportEntry> onChanged;

  @override
  Widget build(BuildContext context) {
    final fields = [
      (
        label: 'Лек',
        value: entry.lectureHours,
        set: (v) => entry.copyWith(lectureHours: v)
      ),
      (
        label: 'ЛР/ПР',
        value: entry.practicalHours,
        set: (v) => entry.copyWith(practicalHours: v)
      ),
      (
        label: 'КП',
        value: entry.courseProjectHours,
        set: (v) => entry.copyWith(courseProjectHours: v)
      ),
      (
        label: 'Конс',
        value: entry.consultationHours,
        set: (v) => entry.copyWith(consultationHours: v)
      ),
      (
        label: 'Доп.к',
        value: entry.additionalAssessmentHours,
        set: (v) => entry.copyWith(additionalAssessmentHours: v)
      ),
      (
        label: 'Экз',
        value: entry.examHours,
        set: (v) => entry.copyWith(examHours: v)
      ),
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

class _SubstitutionsSection extends StatelessWidget {
  const _SubstitutionsSection({
    required this.substitutions,
    required this.locked,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Substitution> substitutions;
  final bool locked;
  final VoidCallback onAdd;
  final ValueChanged<Substitution> onDelete;

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
        if (substitutions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Нет замен', style: TextStyle(color: Colors.grey)),
          )
        else
          ...substitutions.map((substitution) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Гр. ${substitution.group} — ${substitution.date}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${substitution.hours} ч'),
                    if (!locked)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => onDelete(substitution),
                      ),
                  ],
                ),
              )),
      ],
    );
  }
}
