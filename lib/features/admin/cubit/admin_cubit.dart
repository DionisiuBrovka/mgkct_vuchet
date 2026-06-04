import 'package:flutter_bloc/flutter_bloc.dart';

import '../../teacher/repository/vychitka_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  AdminCubit(this._repo) : super(const AdminInitial());

  final VychitkaRepository _repo;

  Future<void> loadMonth(String month, int year) async {
    emit(const AdminLoading());
    try {
      final allTeachers = await _repo.getAllTeacherNames();
      final statuses = await _repo.getMonthStatusesForAll(month, year);
      emit(AdminMonthLoaded(statuses: statuses, allTeachers: allTeachers));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> loadTeacherEntries(
      String teacher, String month, int year) async {
    emit(const AdminLoading());
    try {
      final entries = await _repo.getEntries(teacher, month, year);
      final zameny = await _repo.getZameny(teacher, month, year);
      emit(AdminReviewLoaded(entries: entries, zameny: zameny));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> confirm(
    String teacher,
    String month,
    int year,
    String confirmedBy,
  ) async {
    final loaded = state as AdminReviewLoaded;
    emit(AdminReviewLoaded(
        entries: loaded.entries, zameny: loaded.zameny, isUpdating: true));
    try {
      await _repo.confirmMonth(teacher, month, year, confirmedBy);
      emit(AdminReviewLoaded(
          entries: loaded.entries, zameny: loaded.zameny, isUpdating: false));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> reject(String teacher, String month, int year) async {
    final loaded = state as AdminReviewLoaded;
    emit(AdminReviewLoaded(
        entries: loaded.entries, zameny: loaded.zameny, isUpdating: true));
    try {
      await _repo.rejectMonth(teacher, month, year);
      emit(AdminReviewLoaded(
          entries: loaded.entries, zameny: loaded.zameny, isUpdating: false));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }
}
