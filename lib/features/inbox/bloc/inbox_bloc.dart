import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/features/inbox/bloc/inbox_state.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  final SmsRepository _smsRepository;
  StreamSubscription? _threadsSubscription;

  InboxBloc({required SmsRepository smsRepository})
    : _smsRepository = smsRepository,
      super(InboxInitial()) {
    on<SyncInboxEvent>(_onSyncInbox);
    on<_UpdateThreadsEvent>(_onUpdateThreads);
    on<DeleteThreadEvent>(_onDeleteThread);
    on<BatchDeleteThreadsEvent>(_onBatchDeleteThreads);
  }

  void _onUpdateThreads(_UpdateThreadsEvent event, Emitter<InboxState> emit) {
    emit(InboxLoaded(threads: event.threads));
  }

  Future<void> _onSyncInbox(
    SyncInboxEvent event,
    Emitter<InboxState> emit,
  ) async {
    emit(InboxLoading());

    try {
      // 1. Fire off native sync
      await _smsRepository.syncSms();

      // 2. Cancel any existing subscription
      await _threadsSubscription?.cancel();

      // 3. Listen to Isar updates
      _threadsSubscription = _smsRepository.watchThreads().listen((threads) {
        add(_UpdateThreadsEvent(threads: threads));
      });
    } catch (e) {
      emit(InboxError(message: e.toString()));
    }
  }

  Future<void> _onDeleteThread(
    DeleteThreadEvent event,
    Emitter<InboxState> emit,
  ) async {
    try {
      await _smsRepository.deleteThread(event.address, event.nativeThreadId);
      // The Isar stream will automatically push a new InboxLoaded with thread removed
    } catch (_) {}
  }

  Future<void> _onBatchDeleteThreads(
    BatchDeleteThreadsEvent event,
    Emitter<InboxState> emit,
  ) async {
    try {
      await _smsRepository.deleteThreadsBatch(event.threads);
      // The Isar stream will automatically push a new InboxLoaded with threads removed
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _threadsSubscription?.cancel();
    return super.close();
  }
}

// Internal event for stream updates
class _UpdateThreadsEvent extends InboxEvent {
  final List<ThreadModel> threads;
  const _UpdateThreadsEvent({required this.threads});
}
