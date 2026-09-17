import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain.dart';
import '../../../core/report_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  AdminCubit(this._repo) : super(const AdminInitial());
  final ReportRepository _repo;
  int _request = 0;
  Future<void> loadMonth(int month, int year,
      {String query = '', ReportStatus? status}) async {
    final request = ++_request;
    emit(const AdminLoading());
    try {
      final teachers = await _repo.adminReports(year, month,
          query: query.trim().isEmpty ? null : query.trim(), status: status);
      if (!isClosed && request == _request) {
        emit(AdminMonthLoaded(teachers,
            year: year, month: month, query: query, status: status));
      }
    } catch (error) {
      if (!isClosed && request == _request) emit(AdminError(error.toString()));
    }
  }

  Future<void> loadTeacherEntries(
      String teacher, String month, int year) async {
    final request = ++_request;
    emit(const AdminLoading());
    try {
      final report = await _repo.report(teacher, year, _month(month));
      if (!isClosed && request == _request) emit(AdminReviewLoaded(report));
    } catch (error) {
      if (!isClosed && request == _request) emit(AdminError(error.toString()));
    }
  }

  int _month(String month) =>
      const {
        'Сентябрь': 9,
        'Октябрь': 10,
        'Ноябрь': 11,
        'Декабрь': 12,
        'Январь': 1,
        'Февраль': 2,
        'Март': 3,
        'Апрель': 4,
        'Май': 5,
        'Июнь': 6,
        'Июль': 7
      }[month] ??
      9;
  Future<void> confirm() => _transition('confirm');
  Future<void> reject() => _transition('return');
  Future<void> _transition(String action) async {
    final loaded = state;
    if (loaded is! AdminReviewLoaded ||
        loaded.isUpdating ||
        loaded.report.status != ReportStatus.submitted) {
      return;
    }
    emit(AdminReviewLoaded(loaded.report, isUpdating: true));
    try {
      final report = await _repo.transition(
          loaded.report.teacher.id,
          loaded.report.year,
          loaded.report.month,
          loaded.report.revision,
          action);
      if (!isClosed) {
        emit(AdminReviewLoaded(report, completed: true));
      }
    } catch (error) {
      if (!isClosed) {
        emit(AdminReviewLoaded(loaded.report, error: error.toString()));
      }
    }
  }
}
