import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/report_repository.dart';
import '../models/editable_report.dart';
import 'teaching_report_state.dart';

class TeachingReportCubit extends Cubit<TeachingReportState> {
  TeachingReportCubit(this._repo) : super(const TeachingReportInitial());
  final ReportRepository _repo;
  int _request = 0;
  Future<void> loadMonth(String teacher, int year, int month) async {
    final request = ++_request;
    emit(const TeachingReportLoading());
    try {
      final report = await _repo.report(teacher, year, month);
      if (!isClosed && request == _request) {
        emit(TeachingReportLoaded(EditableReport.fromReport(report)));
      }
    } catch (error) {
      if (!isClosed && request == _request) {
        emit(TeachingReportError(error.toString()));
      }
    }
  }

  void updateValue(String assignmentId, String field, String value) {
    final loaded = state;
    if (loaded is! TeachingReportLoaded || loaded.isSaving) return;
    final editor = loaded.editor.copy()..setValue(assignmentId, field, value);
    emit(loaded.copyWith(editor: editor, error: null));
  }

  Future<void> saveDraft() => _save('save');
  Future<void> submit() => _save('submit');
  Future<void> _save(String action) async {
    final loaded = state;
    if (loaded is! TeachingReportLoaded || loaded.isSaving) return;
    emit(loaded.copyWith(isSaving: true));
    try {
      final input = loaded.editor.input();
      if (input == null) {
        emit(loaded.copyWith(
            isSaving: false, error: 'Проверьте значения часов'));
        return;
      }
      final report = action == 'submit'
          ? await _repo.submit(
              loaded.editor.report.year, loaded.editor.report.month, input)
          : await _repo.save(
              loaded.editor.report.year, loaded.editor.report.month, input);
      if (!isClosed) {
        emit(TeachingReportLoaded(EditableReport.fromReport(report)));
      }
    } catch (error) {
      if (!isClosed) {
        emit(loaded.copyWith(isSaving: false, error: error.toString()));
      }
    }
  }
}
