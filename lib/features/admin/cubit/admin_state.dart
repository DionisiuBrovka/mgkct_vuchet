import 'package:equatable/equatable.dart';

import '../../teacher/models/teaching_report_entry.dart';
import '../../teacher/models/substitution.dart';

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
  const AdminMonthLoaded({
    required this.statuses,
    required this.allTeachers,
    this.isUpdating = false,
  });

  final Map<String, TeachingReportStatus> statuses;
  final List<String> allTeachers;
  final bool isUpdating;

  AdminMonthLoaded copyWith({
    Map<String, TeachingReportStatus>? statuses,
    List<String>? allTeachers,
    bool? isUpdating,
  }) =>
      AdminMonthLoaded(
        statuses: statuses ?? this.statuses,
        allTeachers: allTeachers ?? this.allTeachers,
        isUpdating: isUpdating ?? this.isUpdating,
      );

  @override
  List<Object?> get props => [statuses, allTeachers, isUpdating];
}

class AdminReviewLoaded extends AdminState {
  const AdminReviewLoaded({
    required this.entries,
    required this.substitutions,
    this.isUpdating = false,
  });

  final List<TeachingReportEntry> entries;
  final List<Substitution> substitutions;
  final bool isUpdating;

  @override
  List<Object?> get props => [entries, substitutions, isUpdating];
}

class AdminError extends AdminState {
  const AdminError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
