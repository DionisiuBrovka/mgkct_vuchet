import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../core/domain.dart';
import '../../../core/report_repository.dart';
import '../../../injection.dart';
import '../../../shared/widgets/screen_hint.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late int _academicYear;
  late String _month;
  List<int> _years = [];
  String _query = '';
  ReportStatus? _status;
  Timer? _debounce;
  final _search = TextEditingController();
  String? _periodError;
  int get _monthNumber => const [
        9,
        10,
        11,
        12,
        1,
        2,
        3,
        4,
        5,
        6,
        7
      ][AppConstants.months.indexOf(_month)];
  int get _year => AppConstants.yearForMonth(_month, _academicYear);

  @override
  void initState() {
    super.initState();
    _academicYear = AppConstants.currentAcademicYear();
    _years = [_academicYear];
    final month = DateTime.now().month;
    _month = AppConstants.months[const [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7]
        .indexOf(month == 8 ? 9 : month)];
    _loadPeriods();
    _load();
  }

  Future<void> _loadPeriods() async {
    try {
      final periods = await getIt<ReportRepository>().adminPeriods();
      if (mounted) {
        setState(() {
          _years = {
            _academicYear,
            ...periods.map((p) => p['academicYear'] as int)
          }.toList()
            ..sort((a, b) => b.compareTo(a));
          _periodError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _periodError = '$error');
    }
  }

  Future<void> _load() => context
      .read<AdminCubit>()
      .loadMonth(_monthNumber, _year, query: _query, status: _status);
  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Вычитка · Завуч'), actions: [
        IconButton(
            onPressed: () => context.push('/admin/statistics'),
            tooltip: 'Статистика и Excel',
            icon: const Icon(Icons.bar_chart_outlined)),
        IconButton(
            onPressed: () => context.read<AuthCubit>().logout(),
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout)),
      ]),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        const ScreenHint(
                            title: 'Проверка месячных отчётов',
                            message:
                                'Откройте отчёт на проверке, сверьте часы с годовым планом и подтвердите или верните на доработку. Подтверждённые отчёты доступны только для просмотра.'),
                        const SizedBox(height: 16),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/admin/statistics'),
                                icon: const Icon(Icons.download_outlined),
                                label:
                                    const Text('Годовая статистика и Excel'))),
                        const SizedBox(height: 20),
                        Wrap(spacing: 12, runSpacing: 16, children: [
                          SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<int>(
                                  initialValue: _academicYear,
                                  decoration: const InputDecoration(
                                      labelText: 'Учебный год'),
                                  items: [
                                    for (final y in _years)
                                      DropdownMenuItem(
                                          value: y, child: Text('$y–${y + 1}'))
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _academicYear = v);
                                      _load();
                                    }
                                  })),
                          SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                  initialValue: _month,
                                  decoration:
                                      const InputDecoration(labelText: 'Месяц'),
                                  isExpanded: true,
                                  items: [
                                    for (final month in AppConstants.months)
                                      DropdownMenuItem(
                                          value: month,
                                          child: Text(
                                              '$month ${AppConstants.yearForMonth(month, _academicYear)}'))
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _month = v);
                                      _load();
                                    }
                                  })),
                          SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                  initialValue: '',
                                  decoration: const InputDecoration(
                                      labelText: 'Статус'),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: '', child: Text('Все статусы')),
                                    DropdownMenuItem(
                                        value: 'draft',
                                        child: Text('Черновик')),
                                    DropdownMenuItem(
                                        value: 'submitted',
                                        child: Text('На проверке')),
                                    DropdownMenuItem(
                                        value: 'confirmed',
                                        child: Text('Подтверждён'))
                                  ],
                                  onChanged: (v) {
                                    setState(() => _status =
                                        v == null || v.isEmpty
                                            ? null
                                            : ReportStatus.values.byName(v));
                                    _load();
                                  })),
                          SizedBox(
                              width: 260,
                              child: TextField(
                                  controller: _search,
                                  maxLength: 200,
                                  decoration: InputDecoration(
                                      labelText: 'ФИО преподавателя',
                                      prefixIcon: const Icon(Icons.search),
                                      counterText: '',
                                      suffixIcon: _query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Очистить поиск',
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _debounce?.cancel();
                                                _search.clear();
                                                setState(() => _query = '');
                                                _load();
                                              })),
                                  onChanged: (value) {
                                    setState(() => _query = value);
                                    _debounce?.cancel();
                                    _debounce = Timer(
                                        const Duration(milliseconds: 300),
                                        _load);
                                  })),
                        ]),
                        if (_periodError != null)
                          TextButton(
                              onPressed: _loadPeriods,
                              child: Text(
                                  'Не удалось загрузить годы: $_periodError. Повторить')),
                        const SizedBox(height: 24),
                        BlocBuilder<AdminCubit, AdminState>(
                            builder: (context, state) {
                          if (state is AdminLoading || state is AdminInitial) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (state is AdminError) {
                            return TextButton(
                                onPressed: _load,
                                child: Text('Повторить: ${state.message}'));
                          }
                          if (state is! AdminMonthLoaded) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                    '$_month $_year · Преподавателей: ${state.teachers.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 12),
                                if (state.teachers.isEmpty)
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: Text(
                                          'По выбранным фильтрам преподавателей нет. Измените поиск или статус.')),
                                for (final teacher in state.teachers)
                                  Card(
                                      child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: teacher.status ==
                                                  ReportStatus.draft
                                              ? null
                                              : () async {
                                                  await context.push(
                                                      '/admin/review/${teacher.id}/$_month/$_year');
                                                  if (mounted) _load();
                                                },
                                          child: Padding(
                                              padding: const EdgeInsets.all(18),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(teacher.name,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                        spacing: 12,
                                                        runSpacing: 8,
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        children: [
                                                          StatusBadge(
                                                              teacher.status),
                                                          Text(teacher.status ==
                                                                  ReportStatus
                                                                      .draft
                                                              ? 'Ожидается отправка'
                                                              : teacher.status ==
                                                                      ReportStatus
                                                                          .submitted
                                                                  ? 'Открыть для проверки →'
                                                                  : 'Посмотреть отчёт →'),
                                                        ]),
                                                  ])))),
                              ]);
                        }),
                      ])))));
}
