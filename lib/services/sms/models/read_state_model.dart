import 'package:isar_community/isar.dart';

part 'read_state_model.g.dart';

/// The app's own record of what the user has read, per conversation.
///
/// A full sync rebuilds threads and messages from the Android SMS provider, whose `read` flag
/// only changes when the provider accepts our write (default SMS app, and not every vendor ROM
/// honours it). Without this record, a conversation the user had read came back as unread on the
/// next sync. It survives syncs because it is never cleared by them.
@collection
class ReadStateModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String address;

  /// Messages received at or before this instant count as read.
  DateTime? readUpTo;

  /// Set by "Mark as unread": messages received at or after this instant count as unread, even if
  /// the provider says otherwise.
  DateTime? unreadFrom;

  /// Whether a message received at [timestamp] is read, given the provider's flag.
  bool isRead(DateTime timestamp, {required bool providerRead}) {
    if (unreadFrom != null && !timestamp.isBefore(unreadFrom!)) return false;
    if (readUpTo != null && !timestamp.isAfter(readUpTo!)) return true;
    return providerRead;
  }
}
