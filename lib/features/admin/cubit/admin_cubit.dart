import 'package:flutter_bloc/flutter_bloc.dart';

import '../../teacher/models/teaching_report_entry.dart';
import '../../teacher/repository/teaching_report_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  AdminCubit(this._repo) : super(const AdminInitial());

  final TeachingReportRepository _repo;

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
      final substitutions = await _repo.getSubstitutions(teacher, month, year);
      emit(AdminReviewLoaded(entries: entries, substitutions: substitutions));
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
        entries: loaded.entries,
        substitutions: loaded.substitutions,
        isUpdating: true));
    try {
      await _repo.confirmMonth(teacher, month, year, confirmedBy);
      final now = DateTime.now();
      emit(AdminReviewLoaded(
        entries: loaded.entries
            .map((e) => e.copyWith(
                status: TeachingReportStatus.confirmed,
                confirmedAt: now,
                confirmedBy: confirmedBy))
            .toList(),
        substitutions: loaded.substitutions,
        isUpdating: false,
      ));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> reject(String teacher, String month, int year) async {
    final loaded = state as AdminReviewLoaded;
    emit(AdminReviewLoaded(
        entries: loaded.entries,
        substitutions: loaded.substitutions,
        isUpdating: true));
    try {
      await _repo.rejectMonth(teacher, month, year);
      emit(AdminReviewLoaded(
        entries: loaded.entries
            .map((e) => e.copyWith(status: TeachingReportStatus.draft))
            .toList(),
        substitutions: loaded.substitutions,
        isUpdating: false,
      ));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }
}
