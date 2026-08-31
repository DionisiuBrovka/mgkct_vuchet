import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/teaching_report_entry.dart';
import '../models/substitution.dart';
import '../repository/teaching_report_repository.dart';
import 'teaching_report_state.dart';

class TeachingReportCubit extends Cubit<TeachingReportState> {
  TeachingReportCubit(this._repo) : super(const TeachingReportInitial());
  final TeachingReportRepository _repo;
  int _request = 0;
  Future<void> loadMonth(String teacher, String month, int year) async {
    final request = ++_request;
    emit(const TeachingReportLoading());
    try {
      final report = await _repo.getReport(teacher, month, year);
      if (!isClosed && request == _request) emit(TeachingReportLoaded(report));
    } catch (error) {
      if (!isClosed && request == _request) {
        emit(TeachingReportError(error.toString()));
      }
    }
  }

  void updateEntry(TeachingReportEntry updated) {
    final loaded = state;
    if (loaded is! TeachingReportLoaded || loaded.isSaving) return;
    emit(loaded.copyWith(
        report: loaded.report.copyWith(entries: [
      for (final entry in loaded.entries)
        entry.assignmentId == updated.assignmentId ? updated : entry
    ])));
  }

  Future<void> saveDraft() => _save('save');
  Future<void> submit() => _save('submit');
  Future<void> _save(String action) async {
    final loaded = state;
    if (loaded is! TeachingReportLoaded || loaded.isSaving) return;
    emit(loaded.copyWith(isSaving: true));
    try {
      final report = await _repo.change(loaded.report, action);
      if (!isClosed) emit(TeachingReportLoaded(report));
    } catch (error) {
      if (!isClosed) {
        emit(loaded.copyWith(isSaving: false, error: error.toString()));
      }
    }
  }

  void addSubstitution(Substitution substitution) {
    final loaded = state;
    if (loaded is! TeachingReportLoaded || loaded.isSaving) return;
    emit(loaded.copyWith(
        report: loaded.report.copyWith(substitutions: [
      ...loaded.substitutions,
      substitution.copyWith(id: 'local:${const Uuid().v4()}')
    ])));
  }

  void deleteSubstitution(Substitution substitution) {
    final loaded = state;
    if (loaded is! TeachingReportLoaded || loaded.isSaving) return;
    emit(loaded.copyWith(
        report: loaded.report.copyWith(
            substitutions: loaded.substitutions
                .where((item) => item.id != substitution.id)
                .toList())));
  }
}
