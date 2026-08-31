import 'package:equatable/equatable.dart';
import '../models/report_snapshot.dart';
import '../models/teaching_report_entry.dart';
import '../models/substitution.dart';

abstract class TeachingReportState extends Equatable {
  const TeachingReportState();
  @override
  List<Object?> get props => [];
}

class TeachingReportInitial extends TeachingReportState {
  const TeachingReportInitial();
}

class TeachingReportLoading extends TeachingReportState {
  const TeachingReportLoading();
}

class TeachingReportLoaded extends TeachingReportState {
  const TeachingReportLoaded(this.report, {this.isSaving = false, this.error});
  final ReportSnapshot report;
  final bool isSaving;
  final String? error;
  List<TeachingReportEntry> get entries => report.entries;
  List<Substitution> get substitutions => report.substitutions;
  TeachingReportLoaded copyWith(
          {ReportSnapshot? report, bool? isSaving, String? error}) =>
      TeachingReportLoaded(report ?? this.report,
          isSaving: isSaving ?? this.isSaving, error: error);
  @override
  List<Object?> get props => [report, isSaving, error];
}

class TeachingReportError extends TeachingReportState {
  const TeachingReportError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
