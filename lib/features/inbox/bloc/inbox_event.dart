import 'package:equatable/equatable.dart';

abstract class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

class SyncInboxEvent extends InboxEvent {}

class DeleteThreadEvent extends InboxEvent {
  final String address;
  final String nativeThreadId;

  const DeleteThreadEvent({
    required this.address,
    required this.nativeThreadId,
  });

  @override
  List<Object?> get props => [address, nativeThreadId];
}

class BatchDeleteThreadsEvent extends InboxEvent {
  final List<({String address, String nativeThreadId})> threads;

  const BatchDeleteThreadsEvent({required this.threads});

  @override
  List<Object?> get props => [threads];
}
