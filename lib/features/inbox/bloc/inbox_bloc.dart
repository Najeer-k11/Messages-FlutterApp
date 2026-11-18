import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/features/inbox/bloc/inbox_state.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/thread_prefs_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  final SmsRepository _smsRepository;
  StreamSubscription? _threadsSubscription;
  StreamSubscription? _prefsSubscription;
  List<ThreadModel> _threads = const [];
  Map<String, ThreadPrefsModel> _prefs = const {};
  int _revision = 0;

  InboxBloc({required SmsRepository smsRepository})
    : _smsRepository = smsRepository,
      super(InboxInitial()) {
    on<SyncInboxEvent>(_onSyncInbox);
    on<_UpdateThreadsEvent>(_onUpdateThreads);
    on<DeleteThreadEvent>(_onDeleteThread);
    on<BatchDeleteThreadsEvent>(_onBatchDeleteThreads);
  }

  InboxLoaded _combine() => InboxLoaded.from(_threads, _prefs, ++_revision);

  void _onUpdateThreads(_UpdateThreadsEvent event, Emitter<InboxState> emit) {
    if (event.threads != null) _threads = event.threads!;
    if (event.prefs != null) _prefs = event.prefs!;
    // Don't replace the first-sync spinner with an empty list just because settings arrived.
    if (state is InboxLoading && _threads.isEmpty) return;
    emit(_combine());
  }

  Future<void> _onSyncInbox(
    SyncInboxEvent event,
    Emitter<InboxState> emit,
  ) async {
    final isInitialRun = _threadsSubscription == null;

    if (isInitialRun) {
      _prefs = await _smsRepository.watchPrefs().first;
      _prefsSubscription = _smsRepository.watchPrefs().skip(1).listen((p) => add(_UpdateThreadsEvent(prefs: p)));
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
      _threads = cachedThreads;

      if (cachedThreads.isNotEmpty) {
        emit(_combine());
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
        _threads = await _smsRepository.isar.threadModels.where().sortByTimestampDesc().findAll();
        emit(_combine());
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
    _prefsSubscription?.cancel();
    return super.close();
  }
}

// Internal event for stream updates
class _UpdateThreadsEvent extends InboxEvent {
  final List<ThreadModel>? threads;
  final Map<String, ThreadPrefsModel>? prefs;
  const _UpdateThreadsEvent({this.threads, this.prefs});

  @override
  List<Object?> get props => [threads, prefs];
}
