import 'package:isar_community/isar.dart';

part 'thread_prefs_model.g.dart';

/// The user's own settings for one conversation: pinned, archived, muted, reported as spam, and
/// an unsent draft.
///
/// A full sync clears and rebuilds [ThreadModel]s from the Android SMS provider, so anything the
/// user chose has to live here, keyed by the normalized address, where syncs never touch it.
@collection
class ThreadPrefsModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String address;

  /// Set when pinned; pinned conversations sort by this, oldest pin first.
  DateTime? pinnedAt;

  /// Set when archived. A message received after this brings the conversation back to the inbox,
  /// unless it is muted.
  DateTime? archivedAt;

  bool muted = false;

  /// Reported as spam: lives in the Spam folder and never notifies.
  bool spam = false;

  /// Text typed but not sent.
  String draft = '';

  @ignore
  bool get pinned => pinnedAt != null;

  @ignore
  bool get archived => archivedAt != null;

  /// Nothing set: the record can be deleted.
  @ignore
  bool get isEmpty => pinnedAt == null && archivedAt == null && !muted && !spam && draft.isEmpty;
}
