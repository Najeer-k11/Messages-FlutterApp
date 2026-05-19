import 'package:equatable/equatable.dart';
import 'package:msgs/services/sms/models/thread_model.dart';

abstract class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {}

class InboxLoading extends InboxState {}

class InboxLoaded extends InboxState {
  final List<ThreadModel> threads;

  const InboxLoaded({required this.threads});

  @override
  List<Object?> get props => [threads];
}

class InboxError extends InboxState {
  final String message;

  const InboxError({required this.message});

  @override
  List<Object?> get props => [message];
}
