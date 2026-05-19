import 'dart:async';
import 'dart:isolate';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_state.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/categorization/message_classifier.dart';
import 'package:msgs/services/sms/categorization/otp_parser.dart';
import 'package:msgs/features/banking/widgets/transaction_card.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class HubsEvent extends Equatable {
  const HubsEvent();

  @override
  List<Object?> get props => [];
}

class ProcessThreadsEvent extends HubsEvent {
  final List<ThreadModel> threads;
  const ProcessThreadsEvent({required this.threads});

  @override
  List<Object?> get props => [threads];
}

// ── States ───────────────────────────────────────────────────────────────────

abstract class HubsState extends Equatable {
  const HubsState();

  @override
  List<Object?> get props => [];
}

class HubsInitial extends HubsState {}

class HubsProcessing extends HubsState {}

class HubsLoaded extends HubsState {
  final List<OtpData> activeOtps;
  final List<TransactionData> recentTransactions;

  const HubsLoaded({
    required this.activeOtps,
    required this.recentTransactions,
  });

  @override
  List<Object?> get props => [activeOtps, recentTransactions];
}

// ── Result class for Isolate transfer ────────────────────────────────────────

class HubsResult {
  final List<OtpData> activeOtps;
  final List<TransactionData> recentTransactions;

  HubsResult({required this.activeOtps, required this.recentTransactions});
}

// Top level function for Isolate
HubsResult _parseThreads(List<ThreadModel> threads) {
  final List<OtpData> activeOtps = [];
  final List<TransactionData> recentTransactions = [];

  for (var thread in threads) {
    final category = MessageClassifier.classify(
      thread.lastMessage,
      thread.senderName,
    );
    if (category == MessageCategory.otp) {
      final otpData = OtpParser.extract(
        thread.lastMessage,
        thread.senderName,
      );
      if (otpData != null) {
        activeOtps.add(otpData);
      }
    } else if (category == MessageCategory.banking) {
      final txData = TransactionData.extract(thread.lastMessage);
      if (txData != null) {
        recentTransactions.add(txData);
      }
    }
  }

  return HubsResult(
    activeOtps: activeOtps,
    recentTransactions: recentTransactions,
  );
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class HubsBloc extends Bloc<HubsEvent, HubsState> {
  final InboxBloc _inboxBloc;
  StreamSubscription? _inboxSubscription;

  HubsBloc({required InboxBloc inboxBloc})
      : _inboxBloc = inboxBloc,
        super(HubsInitial()) {
    on<ProcessThreadsEvent>(_onProcessThreads);

    // Listen to InboxBloc changes
    _inboxSubscription = _inboxBloc.stream.listen((inboxState) {
      if (inboxState is InboxLoaded) {
        add(ProcessThreadsEvent(threads: inboxState.threads));
      }
    });

    // Check initial state
    final initialState = _inboxBloc.state;
    if (initialState is InboxLoaded) {
      add(ProcessThreadsEvent(threads: initialState.threads));
    }
  }

  Future<void> _onProcessThreads(
      ProcessThreadsEvent event, Emitter<HubsState> emit) async {
    if (state is HubsInitial) {
      emit(HubsProcessing());
    }

    try {
      // Offload heavy RegEx parsing to a separate background isolate
      final result = await Isolate.run(() => _parseThreads(event.threads));
      emit(HubsLoaded(
        activeOtps: result.activeOtps,
        recentTransactions: result.recentTransactions,
      ));
    } catch (_) {
      // Fallback
      final result = _parseThreads(event.threads);
      emit(HubsLoaded(
        activeOtps: result.activeOtps,
        recentTransactions: result.recentTransactions,
      ));
    }
  }

  @override
  Future<void> close() {
    _inboxSubscription?.cancel();
    return super.close();
  }
}
