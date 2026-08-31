import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../teacher/models/teaching_report_entry.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late String _selectedMonth;
  late int _academicYear;

  // Календарный год выбранного месяца (определяется автоматически)
  int get _calendarYear =>
      AppConstants.yearForMonth(_selectedMonth, _academicYear);

  @override
  void initState() {
    super.initState();
    _academicYear = AppConstants.currentAcademicYear();

    // По умолчанию — текущий месяц (если он входит в список)
    final currentMonthRu = _monthNumToRu(DateTime.now().month);
    _selectedMonth = AppConstants.months.contains(currentMonthRu)
        ? currentMonthRu
        : AppConstants.months.first;

    _load();
  }

  String _monthNumToRu(int m) {
    const map = {
      1: 'Январь',
      2: 'Февраль',
      3: 'Март',
      4: 'Апрель',
      5: 'Май',
      6: 'Июнь',
      7: 'Июль',
      9: 'Сентябрь',
      10: 'Октябрь',
      11: 'Ноябрь',
      12: 'Декабрь',
    };
    return map[m] ?? 'Сентябрь';
  }

  void _load() =>
      context.read<AdminCubit>().loadMonth(_selectedMonth, _calendarYear);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Вычитки — Завуч'),
            Text(
              'Учебный год $_academicYear/${_academicYear + 1}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                // Выбор учебного года
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    initialValue: _academicYear,
                    decoration: const InputDecoration(labelText: 'Уч. год'),
                    items: List.generate(3, (i) => _academicYear - 1 + i)
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y/${y + 1}'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _academicYear = v);
                        _load();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Выбор месяца
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Месяц'),
                    items: AppConstants.months
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                '$m ${AppConstants.yearForMonth(m, _academicYear)}',
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedMonth = v);
                        _load();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<AdminCubit, AdminState>(
              builder: (ctx, state) {
                if (state is AdminLoading || state is AdminInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AdminError) {
                  return Center(child: Text(state.message));
                }
                final loaded = state as AdminMonthLoaded;
                final teachers = loaded.allTeachers;

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: teachers.length,
                    itemBuilder: (_, i) {
                      final teacher = teachers[i];
                      final status = loaded.statuses[teacher] ??
                          TeachingReportStatus.draft;
                      return Card(
                        child: ListTile(
                          title: Text(teacher, overflow: TextOverflow.ellipsis),
                          trailing: StatusBadge(status),
                          onTap: status == TeachingReportStatus.submitted ||
                                  status == TeachingReportStatus.confirmed
                              ? () async {
                                  await context.push(
                                    '/admin/review/$teacher/$_selectedMonth/$_calendarYear',
                                  );
                                  _load();
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
