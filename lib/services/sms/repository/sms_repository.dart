import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:msgs/services/sms/models/message_model.dart';
import 'package:msgs/services/sms/models/thread_model.dart';

class SmsRepository {
  static const MethodChannel _channel = MethodChannel('com.msgs.ndevmsgs/sms');
  final Isar isar;

  SmsRepository({required this.isar});

  static String normalizeAddress(String address) {
    final clean = address.trim();
    if (clean.isEmpty) return '';
    if (RegExp(r'[a-zA-Z]').hasMatch(clean)) {
      return clean.replaceAll(RegExp(r'\s+'), '');
    }
    return clean.replaceAll(RegExp(r'[\s\-()]+'), '');
  }

  /// Full sync of SMS from Native Android to local Isar DB
  Future<void> syncSms() async {
    try {
      // Clean up expired OTPs (from local Isar and native provider) before syncing
      // await deleteExpiredOtps();

      final List<dynamic> result = await _channel.invokeMethod('getAllSms');

      // Fetch contacts to map senderName to contact name if exists
      final List<Map<String, String>> contacts = await getContacts();
      final Map<String, String> contactsMap = {};
      for (final contact in contacts) {
        final name = contact['name'] ?? '';
        final number = contact['number'] ?? '';
        if (name.isNotEmpty && number.isNotEmpty) {
          contactsMap[normalizeAddress(number)] = name;
        }
      }

      final Map<String, ThreadModel> threadsMap = {};
      final List<MessageModel> messagesToSave = [];

      for (var item in result) {
        final map = Map<String, dynamic>.from(item);

        final nativeId = map['id'] as String;
        final rawAddress = map['address'] as String;
        final body = map['body'] as String;
        final date = map['date'] as int;
        final type = map['type'] as int; // 1 = inbox, 2 = sent
        final read = map['read'] as int; // 0 = unread, 1 = read
        final nativeThreadId = map['thread_id'] as String? ?? '';

        // Ignore promotional messages with -P in header
        if (rawAddress.toUpperCase().contains('-P')) {
          continue;
        }

        final address = normalizeAddress(rawAddress);
        // Robust handling of epoch times in seconds vs milliseconds
        int dateVal = date;
        if (dateVal < 1000000000000) {
          dateVal *= 1000;
        }
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          dateVal,
          isUtc: true,
        );
        final isMe = type == 2;
        final isRead = read == 1;

        // Process Message
        final message = MessageModel()
          ..nativeMessageId = nativeId
          ..threadAddress = address
          ..body = body
          ..timestamp = timestamp
          ..isMe = isMe
          ..isRead = isRead;

        messagesToSave.add(message);

        // Process Thread
        if (!threadsMap.containsKey(address)) {
          threadsMap[address] = ThreadModel()
            ..address = address
            ..nativeThreadId = nativeThreadId
            ..senderName = contactsMap[address] ?? rawAddress
            ..lastMessage = body
            ..timestamp = timestamp
            ..unreadCount = isRead ? 0 : 1;
        } else {
          final thread = threadsMap[address]!;
          // Keep most recent thread_id
          if (nativeThreadId.isNotEmpty) {
            thread.nativeThreadId = nativeThreadId;
          }
          if (contactsMap.containsKey(address)) {
            thread.senderName = contactsMap[address]!;
          }
          if (timestamp.isAfter(thread.timestamp)) {
            thread.lastMessage = body;
            thread.timestamp = timestamp;
          }
          if (!isRead && !isMe) {
            thread.unreadCount += 1;
          }
        }
      }

      await isar.writeTxn(() async {
        // Clear old sync completely for full sync implementation
        await isar.threadModels.clear();
        await isar.messageModels.clear();

        await isar.threadModels.putAll(threadsMap.values.toList());
        await isar.messageModels.putAll(messagesToSave);
      });
    } catch (e) {
      throw Exception("Failed to sync SMS: $e");
    }
  }

  /// Delete OTP messages older than 24 hours from both local Isar and native provider
  // Future<void> deleteExpiredOtps() async {
  //   final latestMsg = await isar.messageModels
  //       .where()
  //       .sortByTimestampDesc()
  //       .findFirst();

  //   DateTime referenceTime = DateTime.now();
  //   if (latestMsg != null) {
  //     final diff = referenceTime.difference(latestMsg.timestamp).abs();
  //     // If the latest message timestamp is within 24 hours of device time, trust it
  //     if (diff.inHours < 24) {
  //       referenceTime = latestMsg.timestamp;
  //     }
  //   }

  //   final cutoffTime = referenceTime
  //       .subtract(const Duration(hours: 24))
  //       .toUtc();

  //   // 1. Query Isar for all messages older than cutoffTime (comparing in UTC)
  //   final messages = await isar.messageModels
  //       .filter()
  //       .timestampLessThan(cutoffTime)
  //       .findAll();

  //   final List<MessageModel> otpsToDelete = [];
  //   for (final msg in messages) {
  //     if (MessageClassifier.classify(msg.body, msg.threadAddress) ==
  //         MessageCategory.otp) {
  //       otpsToDelete.add(msg);
  //     }
  //   }

  //   if (otpsToDelete.isEmpty) return;

  //   // 2. Delete natively (best-effort)
  //   for (final msg in otpsToDelete) {
  //     if (!msg.nativeMessageId.startsWith('temp_')) {
  //       try {
  //         await _channel.invokeMethod('deleteSms', {
  //           'messageId': msg.nativeMessageId,
  //         });
  //       } catch (_) {}
  //     }
  //   }

  //   // 3. Delete from local Isar
  //   await isar.writeTxn(() async {
  //     final idsToDelete = otpsToDelete.map((m) => m.id).toList();
  //     await isar.messageModels.deleteAll(idsToDelete);

  //     // Clean up affected threads
  //     final affectedAddresses = otpsToDelete
  //         .map((m) => m.threadAddress)
  //         .toSet();
  //     for (final address in affectedAddresses) {
  //       final thread = await isar.threadModels
  //           .filter()
  //           .addressEqualTo(address)
  //           .findFirst();
  //       if (thread != null) {
  //         final latestMsg = await isar.messageModels
  //             .filter()
  //             .threadAddressEqualTo(address)
  //             .sortByTimestampDesc()
  //             .findFirst();

  //         if (latestMsg != null) {
  //           thread.lastMessage = latestMsg.body;
  //           thread.timestamp = latestMsg.timestamp;
  //           await isar.threadModels.put(thread);
  //         } else {
  //           await isar.threadModels.delete(thread.id);
  //         }
  //       }
  //     }
  //   });
  // }

  /// Watch all threads reactive stream
  Stream<List<ThreadModel>> watchThreads() {
    return isar.threadModels.where().sortByTimestampDesc().watch(
      fireImmediately: true,
    );
  }

  /// Watch messages for a specific thread
  Stream<List<MessageModel>> watchMessagesForThread(String address) {
    final normalized = normalizeAddress(address);
    return isar.messageModels
        .filter()
        .threadAddressEqualTo(normalized)
        .sortByTimestampDesc()
        .watch(fireImmediately: true);
  }

  /// Check if the app is the default SMS app
  Future<bool> isDefaultSmsApp() async {
    try {
      final bool result = await _channel.invokeMethod('isDefaultSmsApp');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Request to become the default SMS app
  Future<bool> requestDefaultSmsApp() async {
    try {
      final bool result = await _channel.invokeMethod('requestDefaultSmsApp');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Delete a thread natively from the Android SMS provider + local Isar
  Future<void> deleteThread(String address, String nativeThreadId) async {
    final normalized = normalizeAddress(address);
    // 1. Delete natively (best-effort — only works if we are default SMS app)
    try {
      if (nativeThreadId.isNotEmpty) {
        await _channel.invokeMethod('deleteThread', {
          'threadId': nativeThreadId,
        });
      }
    } catch (_) {}

    // 2. Remove from local Isar regardless
    await isar.writeTxn(() async {
      await isar.messageModels
          .filter()
          .threadAddressEqualTo(normalized)
          .deleteAll();
      await isar.threadModels.filter().addressEqualTo(normalized).deleteAll();
    });
  }

  /// Mark all messages in a thread as read — natively + in local Isar
  Future<void> markThreadAsRead(String address, String nativeThreadId) async {
    final normalized = normalizeAddress(address);
    // 1. Mark natively (best-effort)
    try {
      if (nativeThreadId.isNotEmpty) {
        await _channel.invokeMethod('markThreadAsRead', {
          'threadId': nativeThreadId,
        });
      }
    } catch (_) {}

    // 2. Update local Isar
    await isar.writeTxn(() async {
      final thread = await isar.threadModels
          .filter()
          .addressEqualTo(normalized)
          .findFirst();
      if (thread != null) {
        thread.unreadCount = 0;
        await isar.threadModels.put(thread);
      }

      final messages = await isar.messageModels
          .filter()
          .threadAddressEqualTo(normalized)
          .isReadEqualTo(false)
          .findAll();
      for (final m in messages) {
        m.isRead = true;
      }
      await isar.messageModels.putAll(messages);
    });
  }

  /// Fetch device contacts via native MethodChannel
  Future<List<Map<String, String>>> getContacts() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getContacts');
      return result.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return {
          'name': (map['name'] as String?) ?? '',
          'number': (map['number'] as String?) ?? '',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Send an SMS message
  Future<void> sendSms(String address, String body) async {
    final normalized = normalizeAddress(address);
    // 1. Optimistic UI update
    final optimisticMessage = MessageModel()
      ..nativeMessageId = "temp_${DateTime.now().millisecondsSinceEpoch}"
      ..threadAddress = normalized
      ..body = body
      ..timestamp = DateTime.now().toUtc()
      ..isMe = true
      ..isRead = true;

    await isar.writeTxn(() async {
      await isar.messageModels.put(optimisticMessage);

      var thread = await isar.threadModels
          .filter()
          .addressEqualTo(normalized)
          .findFirst();
      if (thread == null) {
        // Look up sender name in contacts if possible
        String senderName = address;
        try {
          final contacts = await getContacts();
          for (final contact in contacts) {
            final name = contact['name'] ?? '';
            final number = contact['number'] ?? '';
            if (name.isNotEmpty &&
                number.isNotEmpty &&
                normalizeAddress(number) == normalized) {
              senderName = name;
              break;
            }
          }
        } catch (_) {}

        thread = ThreadModel()
          ..address = normalized
          ..senderName = senderName
          ..lastMessage = body
          ..timestamp = optimisticMessage.timestamp
          ..unreadCount = 0;
      } else {
        thread.lastMessage = body;
        thread.timestamp = optimisticMessage.timestamp;
      }
      await isar.threadModels.put(thread);
    });

    // 2. Call Native API
    try {
      await _channel.invokeMethod('sendSms', {
        'address': normalized,
        'body': body,
      });
    } catch (e) {
      // Revert optimistic insert on failure
      await isar.writeTxn(() async {
        await isar.messageModels.delete(optimisticMessage.id);
      });
      throw Exception("Failed to send SMS: $e");
    }
  }
}
