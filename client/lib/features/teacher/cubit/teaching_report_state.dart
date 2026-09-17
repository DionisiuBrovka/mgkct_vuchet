import 'package:equatable/equatable.dart';
import '../models/editable_report.dart';

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
  const TeachingReportLoaded(this.editor, {this.isSaving = false, this.error});
  final EditableReport editor;
  final bool isSaving;
  final String? error;
  TeachingReportLoaded copyWith(
          {EditableReport? editor, bool? isSaving, String? error}) =>
      TeachingReportLoaded(editor ?? this.editor,
          isSaving: isSaving ?? this.isSaving, error: error);
  @override
  List<Object?> get props => [editor, isSaving, error];
}

class TeachingReportError extends TeachingReportState {
  const TeachingReportError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
