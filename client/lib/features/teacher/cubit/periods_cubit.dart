import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/report_repository.dart';

sealed class PeriodsState {
  const PeriodsState();
}

class PeriodsLoading extends PeriodsState {
  const PeriodsLoading();
}

class PeriodsLoaded extends PeriodsState {
  const PeriodsLoaded(this.periods);

  final List<Map<String, dynamic>> periods;
}

class PeriodsError extends PeriodsState {
  const PeriodsError(this.message);

  final String message;
}

class PeriodsCubit extends Cubit<PeriodsState> {
  PeriodsCubit(this._repository) : super(const PeriodsLoading());

  final ReportRepository _repository;
  int _request = 0;

  Future<void> load() async {
    final request = ++_request;
    emit(const PeriodsLoading());
    try {
      final periods = await _repository.teacherPeriods();
      if (!isClosed && request == _request) {
        emit(PeriodsLoaded(periods));
      }
    } catch (error) {
      if (!isClosed && request == _request) {
        emit(PeriodsError(error.toString()));
      }
    }
  }
}
