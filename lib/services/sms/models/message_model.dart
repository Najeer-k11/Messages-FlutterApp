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
}
