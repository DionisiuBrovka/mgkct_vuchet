import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../injection.dart';
import '../../../shared/widgets/month_status_card.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../models/teaching_report_entry.dart';
import '../repository/teaching_report_repository.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  Map<String, TeachingReportStatus>? _statuses;
  bool _loading = true;
  String? _error;

  late final String _teacher;
  late final String _teacherId;
  late final int _academicYear;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state as AuthAuthenticated;
    _teacher = auth.user.name;
    _teacherId = auth.user.profileId;
    _academicYear = AppConstants.currentAcademicYear();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = await getIt<TeachingReportRepository>()
          .getMonthStatusesForYear(_teacherId, _academicYear);
      if (mounted) {
        setState(() {
          _statuses = statuses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_teacher, overflow: TextOverflow.ellipsis),
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: _loadStatuses,
                                child: const Text('Повторить'),
                              ),
                            ],
                          )
                        : RefreshIndicator(
                            onRefresh: _loadStatuses,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: AppConstants.months.length,
                              itemBuilder: (_, i) {
                                final month = AppConstants.months[i];
                                final year = AppConstants.yearForMonth(
                                    month, _academicYear);
                                final status = _statuses?[month] ??
                                    TeachingReportStatus.draft;
                                return MonthStatusCard(
                                  month: month,
                                  year: year,
                                  status: status,
                                  onTap: () async {
                                    await context
                                        .push('/teacher/fill/$month/$year');
                                    _loadStatuses();
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
