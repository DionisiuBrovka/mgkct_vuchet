import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../models/teaching_report_entry.dart';
import '../models/substitution.dart';
import '../repository/teaching_report_repository.dart';
import 'teaching_report_state.dart';

class TeachingReportCubit extends Cubit<TeachingReportState> {
  TeachingReportCubit(this._repo) : super(const TeachingReportInitial());

  final TeachingReportRepository _repo;
  final _uuid = const Uuid();

  String? _teacher;
  String? _month;
  int? _year;

  Future<void> loadMonth(String teacher, String month, int year) async {
    _teacher = teacher;
    _month = month;
    _year = year;
    emit(const TeachingReportLoading());
    try {
      final assignments = await _repo.getAssignments(
          teacher, AppConstants.academicYearStart(month, year));
      var entries = await _repo.getEntries(teacher, month, year);

      // Create draft entries for assignments that have no record yet
      final existingKeys = {for (final e in entries) '${e.subject}|${e.group}'};
      final newEntries = <TeachingReportEntry>[];
      for (final a in assignments) {
        final key = '${a.subject}|${a.group}';
        if (!existingKeys.contains(key)) {
          newEntries.add(TeachingReportEntry(
            id: _uuid.v4(),
            teacher: teacher,
            month: month,
            year: year,
            subject: a.subject,
            group: a.group,
          ));
        }
      }
      entries = [...entries, ...newEntries];

      final substitutions = await _repo.getSubstitutions(teacher, month, year);
      emit(
          TeachingReportLoaded(entries: entries, substitutions: substitutions));
    } catch (e) {
      emit(TeachingReportError(e.toString()));
    }
  }

  void updateEntry(TeachingReportEntry updated) {
    final loaded = state as TeachingReportLoaded;
    final entries =
        loaded.entries.map((e) => e.id == updated.id ? updated : e).toList();
    emit(loaded.copyWith(entries: entries));
  }

  Future<void> saveDraft() async {
    final loaded = state as TeachingReportLoaded;
    emit(loaded.copyWith(isSaving: true));
    try {
      // Сохраняем и используем возвращённые записи: у новых черновиков сервер
      // назначает id/assignmentId, без этого повторное сохранение создаёт дубли.
      final saved = await _repo.saveOrUpdateEntries(loaded.entries);
      emit(loaded.copyWith(entries: saved, isSaving: false));
    } catch (e) {
      emit(TeachingReportError(e.toString()));
    }
  }

  Future<void> submit() async {
    final loaded = state as TeachingReportLoaded;
    emit(loaded.copyWith(isSaving: true));
    try {
      final saved = await _repo.saveOrUpdateEntries(loaded.entries);
      await _repo.submitMonth(_teacher!, _month!, _year!);
      final updated = saved
          .map((e) => e.copyWith(status: TeachingReportStatus.submitted))
          .toList();
      emit(loaded.copyWith(entries: updated, isSaving: false));
    } catch (e) {
      emit(TeachingReportError(e.toString()));
    }
  }

  Future<void> addSubstitution(Substitution substitution) async {
    final loaded = state as TeachingReportLoaded;
    try {
      await _repo.saveSubstitution(substitution);
      emit(loaded
          .copyWith(substitutions: [...loaded.substitutions, substitution]));
    } catch (e) {
      emit(TeachingReportError(e.toString()));
    }
  }

  Future<void> deleteSubstitution(Substitution substitution) async {
    final loaded = state as TeachingReportLoaded;
    try {
      await _repo.deleteSubstitution(substitution.teacher, substitution.month,
          substitution.year, substitution.date);
      final updated = loaded.substitutions
          .where((x) => !(x.teacher == substitution.teacher &&
              x.date == substitution.date))
          .toList();
      emit(loaded.copyWith(substitutions: updated));
    } catch (e) {
      emit(TeachingReportError(e.toString()));
    }
  }

  // Статусы всех месяцев учебного года для главного экрана преподавателя.
  // Использует один запрос вместо 11 последовательных.
  Future<Map<String, TeachingReportStatus>> loadAllMonthStatuses(
      String teacher, int academicYearStart) {
    return _repo.getMonthStatusesForYear(teacher, academicYearStart);
  }
}
