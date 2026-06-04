import 'package:equatable/equatable.dart';

import '../models/vychitka_entry.dart';
import '../models/zamena.dart';

abstract class VychitkaState extends Equatable {
  const VychitkaState();
  @override
  List<Object?> get props => [];
}

class VychitkaInitial extends VychitkaState {
  const VychitkaInitial();
}

class VychitkaLoading extends VychitkaState {
  const VychitkaLoading();
}

class VychitkaLoaded extends VychitkaState {
  const VychitkaLoaded({
    required this.entries,
    required this.zameny,
    this.isSaving = false,
  });

  final List<VychitkaEntry> entries;
  final List<Zamena> zameny;
  final bool isSaving;

  VychitkaLoaded copyWith({
    List<VychitkaEntry>? entries,
    List<Zamena>? zameny,
    bool? isSaving,
  }) =>
      VychitkaLoaded(
        entries: entries ?? this.entries,
        zameny: zameny ?? this.zameny,
        isSaving: isSaving ?? this.isSaving,
      );

  @override
  List<Object?> get props => [entries, zameny, isSaving];
}

class VychitkaError extends VychitkaState {
  const VychitkaError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
