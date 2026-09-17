import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/report_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  AdminCubit(this._repo) : super(const AdminInitial());
  final ReportRepository _repo;
  int _request = 0;
  Future<void> loadMonth(String month, int year) async {
    final request = ++_request;
    emit(const AdminLoading());
    try {
      final teachers = await _repo.adminReports(year, _month(month));
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
  Future<void> confirm() async =>
      emit(const AdminError('Обновите отчёт перед подтверждением'));
  Future<void> reject() async =>
      emit(const AdminError('Обновите отчёт перед возвратом'));
}
