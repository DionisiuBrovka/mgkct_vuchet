import 'package:equatable/equatable.dart';
import '../../teacher/models/report_snapshot.dart';

abstract class AdminState extends Equatable {
  const AdminState();
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminMonthLoaded extends AdminState {
  const AdminMonthLoaded(this.teachers);
  final List<TeacherSummary> teachers;
  @override
  List<Object?> get props => [teachers];
}

class AdminReviewLoaded extends AdminState {
  const AdminReviewLoaded(this.report,
      {this.isUpdating = false, this.completed = false, this.error});
  final ReportSnapshot report;
  final bool isUpdating;
  final bool completed;
  final String? error;
  @override
  List<Object?> get props => [report, isUpdating, completed, error];
}

class AdminError extends AdminState {
  const AdminError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
