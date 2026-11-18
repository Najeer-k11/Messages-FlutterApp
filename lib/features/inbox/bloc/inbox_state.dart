import 'package:equatable/equatable.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/thread_prefs_model.dart';

abstract class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {}

class InboxLoading extends InboxState {}

class InboxLoaded extends InboxState {
  /// The inbox: neither archived nor spam, pinned conversations first.
  final List<ThreadModel> threads;
  final List<ThreadModel> archived;
  final List<ThreadModel> spam;

  /// Per-conversation settings, keyed by address. Conversations without settings are absent.
  final Map<String, ThreadPrefsModel> prefs;

  /// Bumped on every update: prefs records are mutated in place by Isar, so equality on the map
  /// alone would miss changes.
  final int revision;

  const InboxLoaded({
    required this.threads,
    this.archived = const [],
    this.spam = const [],
    this.prefs = const {},
    this.revision = 0,
  });

  /// Inbox and archived together, newest first: what search and the Money tab look through.
  List<ThreadModel> get notSpam => [...threads, ...archived]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  ThreadPrefsModel? prefsFor(String address) => prefs[address];

  /// Splits [all] (newest first) into inbox, archived and spam using [prefs].
  factory InboxLoaded.from(List<ThreadModel> all, Map<String, ThreadPrefsModel> prefs, int revision) {
    final pinned = <ThreadModel>[], inbox = <ThreadModel>[], archived = <ThreadModel>[], spam = <ThreadModel>[];
    for (final t in all) {
      final p = prefs[t.address];
      if (p?.spam ?? false) {
        spam.add(t);
      } else if (p?.archived ?? false) {
        archived.add(t);
      } else if (p?.pinned ?? false) {
        pinned.add(t);
      } else {
        inbox.add(t);
      }
    }
    pinned.sort((a, b) => prefs[a.address]!.pinnedAt!.compareTo(prefs[b.address]!.pinnedAt!));
    return InboxLoaded(
      threads: [...pinned, ...inbox],
      archived: archived,
      spam: spam,
      prefs: prefs,
      revision: revision,
    );
  }

  @override
  List<Object?> get props => [threads, archived, spam, revision];
}

class InboxError extends InboxState {
  final String message;

  const InboxError({required this.message});

  @override
  List<Object?> get props => [message];
}
