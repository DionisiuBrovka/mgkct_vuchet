import 'package:flutter_bloc/flutter_bloc.dart';
import '../../teacher/repository/teaching_report_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  AdminCubit(this._repo) : super(const AdminInitial());
  final TeachingReportRepository _repo;
  int _request = 0;
  Future<void> loadMonth(String month, int year) async {
    final request = ++_request;
    emit(const AdminLoading());
    try {
      final teachers = await _repo.overview(month, year);
      if (!isClosed && request == _request) emit(AdminMonthLoaded(teachers));
    } catch (error) {
      if (!isClosed && request == _request) emit(AdminError(error.toString()));
    }
  }

  Future<void> loadTeacherEntries(
      String teacher, String month, int year) async {
    final request = ++_request;
    emit(const AdminLoading());
    try {
      final report = await _repo.getReport(teacher, month, year);
      if (!isClosed && request == _request) emit(AdminReviewLoaded(report));
    } catch (error) {
      if (!isClosed && request == _request) emit(AdminError(error.toString()));
    }
  }

  Future<void> confirm() => _change('confirm');
  Future<void> reject() => _change('reject');
  Future<void> _change(String action) async {
    final loaded = state;
    if (loaded is! AdminReviewLoaded || loaded.isUpdating) return;
    emit(AdminReviewLoaded(loaded.report, isUpdating: true));
    try {
      final report = await _repo.change(loaded.report, action);
      if (!isClosed) emit(AdminReviewLoaded(report, completed: true));
    } catch (error) {
      if (!isClosed) {
        emit(AdminReviewLoaded(loaded.report, error: error.toString()));
      }
    }
  }
}
