import 'package:flutter/material.dart';
import '../../../shared/widgets/screen_hint.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/report_repository.dart';
import '../../../injection.dart';
import '../../../shared/widgets/month_status_card.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../cubit/periods_cubit.dart';
import '../models/teaching_report_entry.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  late final String _teacher;
  late final PeriodsCubit _periodsCubit;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state as AuthAuthenticated;
    _teacher = auth.user.name;
    _periodsCubit = PeriodsCubit(getIt<ReportRepository>())..load();
  }

  @override
  void dispose() {
    _periodsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_teacher, overflow: TextOverflow.ellipsis),
            BlocBuilder<PeriodsCubit, PeriodsState>(
              bloc: _periodsCubit,
              builder: (_, state) {
                final periods = state is PeriodsLoaded
                    ? state.periods
                    : <Map<String, dynamic>>[];
                return Text(
                  periods.isEmpty
                      ? 'Загрузка периодов'
                      : 'Учебный год ${periods.first['academicYear']}/${(periods.first['academicYear'] as int) + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.normal),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти из учётной записи',
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        Image.asset(
          'assets/images/back.png',
          fit: BoxFit.cover,
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 6,
              child: SizedBox(
                width: 800,
                child: BlocBuilder<PeriodsCubit, PeriodsState>(
                  bloc: _periodsCubit,
                  builder: (_, state) {
                    if (state is PeriodsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is PeriodsError) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.message),
                          TextButton(
                            onPressed: _periodsCubit.load,
                            child: const Text('Повторить'),
                          ),
                        ],
                      );
                    }
                    final periods = (state as PeriodsLoaded).periods;
                    return RefreshIndicator(
                      onRefresh: _periodsCubit.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: periods.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return const ScreenHint(
                                title: 'Выберите месяц',
                                message:
                                    'Откройте черновик, заполните часы и отправьте отчёт завучу. «На проверке» — ожидайте решения; «Подтверждена» — отчёт принят и доступен только для просмотра. Потяните список вниз, чтобы обновить статусы.');
                          }
                          final period = periods[i - 1];
                          const names = {
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
                            12: 'Декабрь'
                          };
                          final month = names[period['month']]!;
                          final year = period['year'] as int;
                          final status = TeachingReportStatus.values
                              .byName(period['status'] as String);
                          return MonthStatusCard(
                            month: month,
                            year: year,
                            status: status,
                            onTap: () async {
                              await context.push(
                                  '/teacher/fill/${period['month']}/$year');
                              _periodsCubit.load();
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
