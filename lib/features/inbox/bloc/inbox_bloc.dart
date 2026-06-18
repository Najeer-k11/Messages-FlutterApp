import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar_community/isar.dart';
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
    final isInitialRun = _threadsSubscription == null;

    if (isInitialRun) {
      final completer = Completer<List<ThreadModel>>();
      _threadsSubscription = _smsRepository.watchThreads().listen((threads) {
        if (completer.isCompleted) {
          add(_UpdateThreadsEvent(threads: threads));
        } else {
          completer.complete(threads);
        }
      });

      // Wait for the first emission from local Isar DB (extremely fast cache load)
      final cachedThreads = await completer.future;

      if (cachedThreads.isNotEmpty) {
        emit(InboxLoaded(threads: cachedThreads));
      } else {
        emit(InboxLoading());
      }
    }

    try {
      // Perform the native SMS provider sync in background
      await _smsRepository.syncSms();

      // If we were showing the loading spinner because there was no cached data,
      // transition to Loaded once sync is finished.
      if (state is InboxLoading || state is InboxInitial) {
        final currentThreads = await _smsRepository.isar.threadModels
            .where()
            .sortByTimestampDesc()
            .findAll();
        emit(InboxLoaded(threads: currentThreads));
      }
    } catch (e) {
      if (state is! InboxLoaded) {
        emit(InboxError(message: e.toString()));
      }
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
