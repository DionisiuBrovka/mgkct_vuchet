import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../models/vychitka_entry.dart';
import '../models/zamena.dart';
import '../repository/vychitka_repository.dart';
import 'vychitka_state.dart';

class VychitkaCubit extends Cubit<VychitkaState> {
  VychitkaCubit(this._repo) : super(const VychitkaInitial());

  final VychitkaRepository _repo;
  final _uuid = const Uuid();

  String? _teacher;
  String? _month;
  int? _year;

  Future<void> loadMonth(String teacher, String month, int year) async {
    _teacher = teacher;
    _month = month;
    _year = year;
    emit(const VychitkaLoading());
    try {
      final assignments = await _repo.getAssignments(
          teacher, AppConstants.academicYearStart(month, year));
      var entries = await _repo.getEntries(teacher, month, year);

      // Create draft entries for assignments that have no record yet
      final existingKeys = {
        for (final e in entries) '${e.subject}|${e.group}'
      };
      final newEntries = <VychitkaEntry>[];
      for (final a in assignments) {
        final key = '${a.subject}|${a.group}';
        if (!existingKeys.contains(key)) {
          newEntries.add(VychitkaEntry(
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

      final zameny = await _repo.getZameny(teacher, month, year);
      emit(VychitkaLoaded(entries: entries, zameny: zameny));
    } catch (e) {
      emit(VychitkaError(e.toString()));
    }
  }

  void updateEntry(VychitkaEntry updated) {
    final loaded = state as VychitkaLoaded;
    final entries = loaded.entries
        .map((e) => e.id == updated.id ? updated : e)
        .toList();
    emit(loaded.copyWith(entries: entries));
  }

  Future<void> saveDraft() async {
    final loaded = state as VychitkaLoaded;
    emit(loaded.copyWith(isSaving: true));
    try {
      // Сохраняем и используем возвращённые записи: у новых черновиков сервер
      // назначает id/assignmentId, без этого повторное сохранение создаёт дубли.
      final saved = await _repo.saveOrUpdateEntries(loaded.entries);
      emit(loaded.copyWith(entries: saved, isSaving: false));
    } catch (e) {
      emit(VychitkaError(e.toString()));
    }
  }

  Future<void> submit() async {
    final loaded = state as VychitkaLoaded;
    emit(loaded.copyWith(isSaving: true));
    try {
      final saved = await _repo.saveOrUpdateEntries(loaded.entries);
      await _repo.submitMonth(_teacher!, _month!, _year!);
      final updated = saved
          .map((e) => e.copyWith(status: VychitkaStatus.submitted))
          .toList();
      emit(loaded.copyWith(entries: updated, isSaving: false));
    } catch (e) {
      emit(VychitkaError(e.toString()));
    }
  }

  Future<void> addZamena(Zamena z) async {
    final loaded = state as VychitkaLoaded;
    try {
      await _repo.saveZamena(z);
      emit(loaded.copyWith(zameny: [...loaded.zameny, z]));
    } catch (e) {
      emit(VychitkaError(e.toString()));
    }
  }

  Future<void> deleteZamena(Zamena z) async {
    final loaded = state as VychitkaLoaded;
    try {
      await _repo.deleteZamena(z.teacher, z.month, z.year, z.date);
      final updated = loaded.zameny
          .where((x) => !(x.teacher == z.teacher && x.date == z.date))
          .toList();
      emit(loaded.copyWith(zameny: updated));
    } catch (e) {
      emit(VychitkaError(e.toString()));
    }
  }

  // Статусы всех месяцев учебного года для главного экрана преподавателя.
  // Использует один запрос вместо 11 последовательных.
  Future<Map<String, VychitkaStatus>> loadAllMonthStatuses(
      String teacher, int academicYearStart) {
    return _repo.getMonthStatusesForYear(teacher, academicYearStart);
  }
}
