import 'package:equatable/equatable.dart';

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
  const TeachingReportLoaded({
    required this.entries,
    required this.substitutions,
    this.isSaving = false,
  });

  final List<TeachingReportEntry> entries;
  final List<Substitution> substitutions;
  final bool isSaving;

  TeachingReportLoaded copyWith({
    List<TeachingReportEntry>? entries,
    List<Substitution>? substitutions,
    bool? isSaving,
  }) =>
      TeachingReportLoaded(
        entries: entries ?? this.entries,
        substitutions: substitutions ?? this.substitutions,
        isSaving: isSaving ?? this.isSaving,
      );

  @override
  List<Object?> get props => [entries, substitutions, isSaving];
}

class TeachingReportError extends TeachingReportState {
  const TeachingReportError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
