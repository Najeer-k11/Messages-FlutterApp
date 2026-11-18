import 'package:isar_community/isar.dart';

part 'message_model.g.dart';

@collection
class MessageModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String nativeMessageId; // Maps to Android's _id

  @Index()
  late String threadAddress;

  late String body;
  late DateTime timestamp;
  late bool isMe;
  late bool isRead;

  /// MMS media parts, each `<content uri>|<mime type>`.
  List<String> media = [];

  /// Outgoing message still in the outbox / queued.
  bool pending = false;

  /// Outgoing message that failed to send.
  bool failed = false;

  /// Outgoing SMS the carrier confirmed was delivered (delivery report received).
  bool delivered = false;
}
