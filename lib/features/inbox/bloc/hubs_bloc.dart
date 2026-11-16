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

  const HubsLoaded({required this.activeOtps, required this.recentTransactions});

  @override
  List<Object?> get props => [activeOtps, recentTransactions];
}

// ── Result class for Isolate transfer ────────────────────────────────────────

class HubsResult {
  final List<OtpData> activeOtps;
  final List<TransactionData> recentTransactions;

  HubsResult({required this.activeOtps, required this.recentTransactions});
}

/// How long a code counts as active when its message states no validity.
const _defaultOtpValidity = Duration(minutes: 10);

// Top level function for Isolate
HubsResult _parseThreads(List<ThreadModel> threads, DateTime now) {
  final List<OtpData> activeOtps = [];
  final List<TransactionData> recentTransactions = [];

  for (var thread in threads) {
    final category = MessageClassifier.classify(thread.lastMessage, thread.senderName);
    if (category == MessageCategory.otp) {
      final otpData = OtpParser.extract(thread.lastMessage, thread.senderName);
      // Only codes still inside their validity window are "active". Previously the last OTP of
      // every sender was shown forever, however old.
      if (otpData != null) {
        final expiresAt = thread.timestamp.add(otpData.validity ?? _defaultOtpValidity);
        final remaining = expiresAt.difference(now);
        if (!remaining.isNegative) {
          activeOtps.add(OtpData(code: otpData.code, serviceName: otpData.serviceName, validity: remaining));
        }
      }
    } else if (category == MessageCategory.banking) {
      final txData = TransactionData.extract(thread.lastMessage);
      if (txData != null) {
        recentTransactions.add(txData);
      }
    }
  }

  return HubsResult(activeOtps: activeOtps, recentTransactions: recentTransactions);
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class HubsBloc extends Bloc<HubsEvent, HubsState> {
  final InboxBloc _inboxBloc;
  StreamSubscription? _inboxSubscription;
  Timer? _expiryTicker;
  List<ThreadModel> _lastThreads = const [];

  HubsBloc({required InboxBloc inboxBloc}) : _inboxBloc = inboxBloc, super(HubsInitial()) {
    on<ProcessThreadsEvent>(_onProcessThreads);

    // Listen to InboxBloc changes
    _inboxSubscription = _inboxBloc.stream.listen((inboxState) {
      if (inboxState is InboxLoaded) {
        add(ProcessThreadsEvent(threads: inboxState.threads));
      }
    });

    // Re-evaluate periodically so expired codes drop off and remaining time stays current.
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastThreads.isNotEmpty) add(ProcessThreadsEvent(threads: _lastThreads));
    });

    // Check initial state
    final initialState = _inboxBloc.state;
    if (initialState is InboxLoaded) {
      add(ProcessThreadsEvent(threads: initialState.threads));
    }
  }

  Future<void> _onProcessThreads(ProcessThreadsEvent event, Emitter<HubsState> emit) async {
    if (state is HubsInitial) {
      emit(HubsProcessing());
    }
    _lastThreads = event.threads;
    final now = DateTime.now().toUtc();

    try {
      // Offload heavy RegEx parsing to a separate background isolate
      final result = await Isolate.run(() => _parseThreads(event.threads, now));
      emit(HubsLoaded(activeOtps: result.activeOtps, recentTransactions: result.recentTransactions));
    } catch (_) {
      // Fallback
      final result = _parseThreads(event.threads, now);
      emit(HubsLoaded(activeOtps: result.activeOtps, recentTransactions: result.recentTransactions));
    }
  }

  @override
  Future<void> close() {
    _inboxSubscription?.cancel();
    _expiryTicker?.cancel();
    return super.close();
  }
}
