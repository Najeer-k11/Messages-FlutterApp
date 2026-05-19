import 'package:isar_community/isar.dart';

part 'thread_model.g.dart';

@collection
class ThreadModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String address;

  /// Native Android thread_id — used for native delete / mark-as-read via ContentResolver
  String nativeThreadId = '';

  late String senderName;
  late String lastMessage;
  late DateTime timestamp;
  int unreadCount = 0;
}
