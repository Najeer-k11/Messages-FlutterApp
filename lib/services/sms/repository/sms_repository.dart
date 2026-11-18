import 'dart:async';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:msgs/services/sms/models/message_model.dart';
import 'package:msgs/services/sms/models/read_state_model.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/thread_prefs_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmsRepository {
  static const MethodChannel _channel = MethodChannel('com.msgs.ndevmsgs/sms');
  final Isar isar;
  Timer? _syncDebounce;
  final StreamController<Map<String, String>> _intentStreamController =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get intentStream => _intentStreamController.stream;

  final StreamController<bool> _mmsResultController = StreamController<bool>.broadcast();

  /// Completion of each MMS send (true = sent). Delivered by the platform asynchronously.
  Stream<bool> get mmsSendResults => _mmsResultController.stream;

  SmsRepository({required this.isar}) {
    _channel.setMethodCallHandler(_handleMethodCall);
    // Re-send the mute list on start, in case the native copy was cleared (app data, upgrade).
    _syncSilenced();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      _syncDebounce?.cancel();
      _syncDebounce = Timer(const Duration(milliseconds: 500), () {
        syncSms();
      });
    } else if (call.method == 'onMmsSendResult') {
      final ok = call.arguments == true;
      await _resolvePendingMms(ok);
      _mmsResultController.add(ok);
    } else if (call.method == 'onNewIntentReceived') {
      final data = Map<String, String>.from(call.arguments);
      _intentStreamController.add(data);
    }
  }

  Future<Map<String, String>?> getPendingIntentData() async {
    try {
      final result = await _channel.invokeMethod('getPendingIntentData');
      if (result != null) {
        return Map<String, String>.from(result);
      }
    } catch (_) {}
    return null;
  }

  /// DLT sender IDs end in a category suffix: -P promotional, -S service, -T transactional,
  /// -G government. Only -P is promotional. A substring match on "-P" would also drop senders
  /// such as "VM-PAYTMB-S" or "AX-PHONPE".
  static bool isPromotionalSender(String address) => address.trim().toUpperCase().endsWith('-P');

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

      // Conversations with blocked senders stay in the provider (unblocking brings them back)
      // but are kept out of the inbox.
      final blocked = await _blockedAmong({for (final item in result) (item as Map)['address'] as String});

      final Map<String, ThreadModel> threadsMap = {};
      // Newest received message per conversation, to bring archived conversations back.
      final Map<String, DateTime> lastReceived = {};
      final List<MessageModel> messagesToSave = [];
      // The app's own read state wins over the provider's flag, which our writes may not reach.
      final readStates = {for (final r in await isar.readStateModels.where().findAll()) r.address: r};

      for (var item in result) {
        final map = Map<String, dynamic>.from(item);

        final nativeId = map['id'] as String;
        final rawAddress = map['address'] as String;
        final body = map['body'] as String;
        final date = map['date'] as int;
        // SMS type / MMS msg_box: 1 inbox, 2 sent, 3 draft, 4 outbox, 5 failed, 6 queued.
        final type = map['type'] as int;
        final read = map['read'] as int; // 0 = unread, 1 = read
        final nativeThreadId = map['thread_id'] as String? ?? '';

        if (isPromotionalSender(rawAddress)) continue;
        if (blocked.contains(rawAddress)) continue;
        if (type == 3) continue; // drafts are not conversation messages
        final media = (map['media'] as List?)?.cast<String>() ?? const <String>[];

        final address = normalizeAddress(rawAddress);
        // Robust handling of epoch times in seconds vs milliseconds
        int dateVal = date;
        if (dateVal < 1000000000000) {
          dateVal *= 1000;
        }
        final timestamp = DateTime.fromMillisecondsSinceEpoch(dateVal, isUtc: true);
        // Everything except the inbox is ours. Treating only "sent" as ours showed outbox, queued
        // and failed messages as received.
        final isMe = type != 1;
        final isRead = isMe || (readStates[address]?.isRead(timestamp, providerRead: read == 1) ?? read == 1);

        // Process Message
        final message = MessageModel()
          ..nativeMessageId = nativeId
          ..threadAddress = address
          ..body = body
          ..timestamp = timestamp
          ..isMe = isMe
          ..isRead = isRead
          ..media = media
          ..pending = type == 4 || type == 6
          ..failed = type == 5
          ..delivered = type == 2 && map['status'] == 0;

        if (!isMe && (lastReceived[address]?.isBefore(timestamp) ?? true)) lastReceived[address] = timestamp;

        messagesToSave.add(message);

        final resolvedSenderName = map['sender_name'] as String? ?? contactsMap[address] ?? rawAddress;

        // Process Thread
        if (!threadsMap.containsKey(address)) {
          threadsMap[address] = ThreadModel()
            ..address = address
            ..nativeThreadId = nativeThreadId
            ..senderName = resolvedSenderName
            ..lastMessage = body
            ..lastHasMedia = media.isNotEmpty
            ..timestamp = timestamp
            ..unreadCount = (!isRead && !isMe) ? 1 : 0;
        } else {
          final thread = threadsMap[address]!;
          // Keep most recent thread_id
          if (nativeThreadId.isNotEmpty) {
            thread.nativeThreadId = nativeThreadId;
          }
          thread.senderName = resolvedSenderName;
          if (timestamp.isAfter(thread.timestamp)) {
            thread.lastMessage = body;
            thread.lastHasMedia = media.isNotEmpty;
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

        // A new message in an archived conversation brings it back, unless it is muted or spam.
        final archived = await isar.threadPrefsModels.filter().archivedAtIsNotNull().findAll();
        final revived = [
          for (final p in archived)
            if (!p.muted && !p.spam && (lastReceived[p.address]?.isAfter(p.archivedAt!) ?? false))
              p..archivedAt = null,
        ];
        if (revived.isNotEmpty) await isar.threadPrefsModels.putAll(revived);
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
    return isar.threadModels.where().sortByTimestampDesc().watch(fireImmediately: true);
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

  /// Get messages for a thread synchronously from local cache
  List<MessageModel> getMessagesForThreadSync(String address) {
    final normalized = normalizeAddress(address);
    return isar.messageModels.filter().threadAddressEqualTo(normalized).sortByTimestampDesc().findAllSync();
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

  /// Batch delete multiple threads natively from the Android SMS provider + local Isar
  Future<void> deleteThreadsBatch(List<({String address, String nativeThreadId})> threads) async {
    // 1. Delete natively (best-effort for each thread)
    for (final t in threads) {
      try {
        if (t.nativeThreadId.isNotEmpty) {
          await _channel.invokeMethod('deleteThread', {'threadId': t.nativeThreadId});
        }
      } catch (_) {}
    }

    // 2. Remove all from local Isar in a single transaction
    final normalizedAddresses = threads.map((t) => normalizeAddress(t.address)).toList();

    await isar.writeTxn(() async {
      for (final address in normalizedAddresses) {
        await isar.messageModels.filter().threadAddressEqualTo(address).deleteAll();
        await isar.threadModels.filter().addressEqualTo(address).deleteAll();
        await isar.readStateModels.filter().addressEqualTo(address).deleteAll();
        await isar.threadPrefsModels.filter().addressEqualTo(address).deleteAll();
      }
    });
    await _syncSilenced();
  }

  /// Delete a thread natively from the Android SMS provider + local Isar
  Future<void> deleteThread(String address, String nativeThreadId) async {
    final normalized = normalizeAddress(address);
    // 1. Delete natively (best-effort — only works if we are default SMS app)
    try {
      if (nativeThreadId.isNotEmpty) {
        await _channel.invokeMethod('deleteThread', {'threadId': nativeThreadId});
      }
    } catch (_) {}

    // 2. Remove from local Isar regardless
    await isar.writeTxn(() async {
      await isar.messageModels.filter().threadAddressEqualTo(normalized).deleteAll();
      await isar.threadModels.filter().addressEqualTo(normalized).deleteAll();
      await isar.readStateModels.filter().addressEqualTo(normalized).deleteAll();
      await isar.threadPrefsModels.filter().addressEqualTo(normalized).deleteAll();
    });
    await _syncSilenced();
  }

  /// Mark all messages in a thread as read — natively + in local Isar
  Future<void> markThreadAsRead(String address, String nativeThreadId) async {
    final normalized = normalizeAddress(address);
    // 1. Mark natively (best-effort)
    try {
      if (nativeThreadId.isNotEmpty) {
        await _channel.invokeMethod('markThreadAsRead', {'threadId': nativeThreadId, 'address': address});
      }
    } catch (_) {}

    // 2. Update local Isar, and record the read so the next sync cannot undo it.
    await isar.writeTxn(() async {
      await _recordRead(normalized);
      final thread = await isar.threadModels.filter().addressEqualTo(normalized).findFirst();
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

  /// Mark several threads read at once (selection mode): natively per thread, then one Isar
  /// transaction for all of them.
  Future<void> markThreadsAsRead(List<({String address, String nativeThreadId})> threads) async {
    for (final t in threads) {
      try {
        if (t.nativeThreadId.isNotEmpty) {
          await _channel.invokeMethod('markThreadAsRead', {'threadId': t.nativeThreadId, 'address': t.address});
        }
      } catch (_) {}
    }
    await isar.writeTxn(() async {
      for (final t in threads) {
        final normalized = normalizeAddress(t.address);
        await _recordRead(normalized);
        final thread = await isar.threadModels.filter().addressEqualTo(normalized).findFirst();
        if (thread != null && thread.unreadCount != 0) {
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
      }
    });
  }

  /// Mark a thread as unread — natively (so it survives the next full sync) + in local Isar.
  Future<void> markThreadAsUnread(String address, String nativeThreadId) async {
    final normalized = normalizeAddress(address);
    try {
      if (nativeThreadId.isNotEmpty) {
        await _channel.invokeMethod('markThreadAsUnread', {'threadId': nativeThreadId});
      }
    } catch (_) {}
    await isar.writeTxn(() async {
      final thread = await isar.threadModels.filter().addressEqualTo(normalized).findFirst();
      if (thread != null) {
        thread.unreadCount = 1;
        await isar.threadModels.put(thread);
      }
      // Mark the latest received message as unread in local Isar
      final latestReceived = await isar.messageModels
          .filter()
          .threadAddressEqualTo(normalized)
          .isMeEqualTo(false)
          .sortByTimestampDesc()
          .findFirst();
      if (latestReceived != null) {
        latestReceived.isRead = false;
        await isar.messageModels.put(latestReceived);
        // Record it so a sync doesn't flip it back to read from the provider's flag.
        final state = await _readState(normalized);
        state
          ..unreadFrom = latestReceived.timestamp
          ..readUpTo = null;
        await isar.readStateModels.put(state);
      }
    });
  }

  Future<ReadStateModel> _readState(String normalizedAddress) async =>
      await isar.readStateModels.filter().addressEqualTo(normalizedAddress).findFirst() ??
      (ReadStateModel()..address = normalizedAddress);

  /// Records that everything received in this conversation so far has been read. Must run inside
  /// a write transaction.
  Future<void> _recordRead(String normalizedAddress) async {
    final state = await _readState(normalizedAddress);
    state
      ..readUpTo = DateTime.now().toUtc()
      ..unreadFrom = null;
    await isar.readStateModels.put(state);
  }

  /// Search messages by body text — used for deep search in the search screen
  Future<List<String>> searchMessageAddresses(String query) async {
    if (query.isEmpty) return [];
    try {
      final messages = await isar.messageModels.filter().bodyContains(query, caseSensitive: false).findAll();
      return messages.map((m) => m.threadAddress).toSet().toList();
    } catch (_) {
      return [];
    }
  }

  /// Get threads for a list of addresses — used by search screen for deep results
  Future<List<ThreadModel>> getThreadsByAddresses(List<String> addresses) async {
    final results = <ThreadModel>[];
    for (final address in addresses) {
      final thread = await isar.threadModels.filter().addressEqualTo(address).findFirst();
      if (thread != null) results.add(thread);
    }
    return results;
  }

  /// The saved contact for [phone] (a contacts lookup URI), or null if the number isn't saved.
  Future<String?> findContact(String phone) async {
    try {
      return await _channel.invokeMethod<String>('findContact', {'phone': phone});
    } catch (_) {
      return null;
    }
  }

  /// Opens a saved contact's card.
  Future<void> openContact(String lookupUri) => _channel.invokeMethod('openContact', {'uri': lookupUri});

  /// Opens the system "new contact" screen with [phone] filled in.
  Future<void> addContact(String phone) async {
    await _channel.invokeMethod('addContact', {'phone': phone});
  }

  // ── Per-conversation settings ────────────────────────────────────────────────────────────────

  /// Every conversation's settings, keyed by normalized address. Emits on any change.
  Stream<Map<String, ThreadPrefsModel>> watchPrefs() => isar.threadPrefsModels
      .where()
      .watch(fireImmediately: true)
      .map((all) => {for (final p in all) p.address: p});

  ThreadPrefsModel? prefsFor(String address) =>
      isar.threadPrefsModels.filter().addressEqualTo(normalizeAddress(address)).findFirstSync();

  /// Applies [change] to the settings of each of [addresses] in one transaction, dropping records
  /// that end up empty.
  Future<void> _updatePrefs(Iterable<String> addresses, void Function(ThreadPrefsModel p) change) async {
    await isar.writeTxn(() async {
      for (final address in addresses.map(normalizeAddress).toSet()) {
        final p =
            await isar.threadPrefsModels.filter().addressEqualTo(address).findFirst() ??
            (ThreadPrefsModel()..address = address);
        change(p);
        if (p.isEmpty) {
          if (p.id != Isar.autoIncrement) await isar.threadPrefsModels.delete(p.id);
        } else {
          await isar.threadPrefsModels.put(p);
        }
      }
    });
  }

  Future<void> setPinned(Iterable<String> addresses, bool pinned) => _updatePrefs(addresses, (p) {
    if (pinned) {
      p.pinnedAt ??= DateTime.now().toUtc();
      p.archivedAt = null;
    } else {
      p.pinnedAt = null;
    }
  });

  Future<void> setArchived(Iterable<String> addresses, bool archived) => _updatePrefs(addresses, (p) {
    if (archived) {
      p.archivedAt = DateTime.now().toUtc();
      p.pinnedAt = null;
    } else {
      p.archivedAt = null;
    }
  });

  Future<void> setMuted(Iterable<String> addresses, bool muted) async {
    await _updatePrefs(addresses, (p) => p.muted = muted);
    await _syncSilenced();
  }

  /// Moves conversations to (or out of) the Spam folder. Spam never notifies.
  Future<void> setSpam(Iterable<String> addresses, bool spam) async {
    await _updatePrefs(addresses, (p) {
      p.spam = spam;
      if (spam) p.pinnedAt = p.archivedAt = null;
    });
    await _syncSilenced();
  }

  Future<void> saveDraft(String address, String text) async {
    final draft = text.trim().isEmpty ? '' : text;
    if ((prefsFor(address)?.draft ?? '') == draft) return;
    await _updatePrefs([address], (p) => p.draft = draft);
  }

  /// Tells the native receivers which conversations must not notify.
  Future<void> _syncSilenced() async {
    try {
      final quiet = await isar.threadPrefsModels.filter().mutedEqualTo(true).or().spamEqualTo(true).findAll();
      await _channel.invokeMethod('setSilenced', {'addresses': [for (final p in quiet) p.address]});
    } catch (_) {}
  }

  static const _deliveryReportsKey = 'delivery_reports';

  Future<bool> deliveryReportsEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_deliveryReportsKey) ?? true;

  Future<void> setDeliveryReports(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_deliveryReportsKey, enabled);

  /// Whether this app may use the system block list (only as the default SMS app).
  Future<bool> canBlockNumbers() async {
    try {
      return await _channel.invokeMethod<bool>('canBlockNumbers') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBlocked(String address) async {
    try {
      return await _channel.invokeMethod<bool>('isBlocked', {'address': address}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The raw addresses in [addresses] that are on the block list.
  Future<Set<String>> _blockedAmong(Set<String> addresses) async {
    if (addresses.isEmpty) return const {};
    try {
      final result = await _channel.invokeListMethod<String>('filterBlocked', {'addresses': addresses.toList()});
      return {...?result};
    } catch (_) {
      return const {};
    }
  }

  /// Adds [address] to the system block list (shared with the Phone app) and drops its
  /// conversation from the inbox. Messages stay on the device; unblocking restores them.
  Future<void> blockNumber(String address) async {
    final ok = await _channel.invokeMethod<bool>('blockNumber', {'address': address}) ?? false;
    if (!ok) throw Exception('Number could not be blocked');
    final normalized = normalizeAddress(address);
    await isar.writeTxn(() async {
      await isar.messageModels.filter().threadAddressEqualTo(normalized).deleteAll();
      await isar.threadModels.filter().addressEqualTo(normalized).deleteAll();
    });
  }

  /// Removes [address] from the block list and brings its conversation back.
  Future<void> unblockNumber(String address) async {
    await _channel.invokeMethod<bool>('unblockNumber', {'address': address});
    await syncSms();
  }

  /// Numbers on the system block list, newest first.
  Future<List<String>> getBlockedNumbers() async =>
      await _channel.invokeListMethod<String>('getBlockedNumbers') ?? const [];

  /// Opens the system contact picker; returns the chosen name and number, or null if cancelled.
  Future<({String name, String number})?> pickContact() async {
    final result = await _channel.invokeMapMethod<String, String>('pickContact');
    if (result == null) return null;
    return (name: result['name'] ?? '', number: result['number'] ?? '');
  }

  /// Fetch device contacts via native MethodChannel
  Future<List<Map<String, String>>> getContacts() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getContacts');
      return result.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return {'name': (map['name'] as String?) ?? '', 'number': (map['number'] as String?) ?? ''};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Opens the system photo picker. Returns content Uris (empty when cancelled).
  Future<List<String>> pickMedia() async {
    final result = await _channel.invokeListMethod<String>('pickMedia');
    return result ?? const [];
  }

  /// JPEG bytes of an image Uri (picked attachment or MMS part), downscaled to [maxSide].
  Future<Uint8List?> readMedia(String uri, {int maxSide = 1080}) =>
      _channel.invokeMethod<Uint8List>('readMedia', {'uri': uri, 'maxSide': maxSide});

  /// Send an MMS with [attachments] (content Uris) and optional text. Images are compressed
  /// natively to the carrier's size limit.
  Future<void> sendMms(String address, String body, List<String> attachments) async {
    final normalized = normalizeAddress(address);
    final optimistic = MessageModel()
      ..nativeMessageId = "temp_${DateTime.now().millisecondsSinceEpoch}"
      ..threadAddress = normalized
      ..body = body
      ..timestamp = DateTime.now().toUtc()
      ..isMe = true
      ..isRead = true
      ..pending = true
      ..media = [for (final u in attachments) '$u|image/*'];

    await isar.writeTxn(() async {
      await isar.messageModels.put(optimistic);
      final thread = await isar.threadModels.filter().addressEqualTo(normalized).findFirst();
      if (thread != null) {
        thread
          ..lastMessage = body
          ..lastHasMedia = true
          ..timestamp = optimistic.timestamp;
        await isar.threadModels.put(thread);
      }
    });

    try {
      await _channel.invokeMethod('sendMms', {'address': normalized, 'body': body, 'attachments': attachments});
    } catch (e) {
      await isar.writeTxn(() async {
        optimistic
          ..pending = false
          ..failed = true;
        await isar.messageModels.put(optimistic);
      });
      throw Exception('Failed to send MMS: $e');
    }
  }

  /// Resolves the oldest optimistic MMS still marked sending. On success the provider now holds
  /// the real message, so a sync replaces it; on failure it is marked "Not sent" in place.
  Future<void> _resolvePendingMms(bool ok) async {
    final pending = await isar.messageModels
        .filter()
        .nativeMessageIdStartsWith('temp_')
        .pendingEqualTo(true)
        .mediaIsNotEmpty()
        .sortByTimestamp()
        .findFirst();
    if (pending != null) {
      await isar.writeTxn(() async {
        pending
          ..pending = false
          ..failed = !ok;
        await isar.messageModels.put(pending);
      });
    }
    if (ok) await syncSms();
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

    // Resolve a contact name for a brand-new thread *before* opening the write transaction:
    // a platform-channel round trip inside writeTxn holds Isar's write lock for its duration.
    String? senderName;
    final exists = await isar.threadModels.filter().addressEqualTo(normalized).count() > 0;
    if (!exists) {
      senderName = address;
      try {
        final contacts = await getContacts();
        for (final contact in contacts) {
          final name = contact['name'] ?? '';
          final number = contact['number'] ?? '';
          if (name.isNotEmpty && number.isNotEmpty && normalizeAddress(number) == normalized) {
            senderName = name;
            break;
          }
        }
      } catch (_) {}
    }

    await isar.writeTxn(() async {
      await isar.messageModels.put(optimisticMessage);

      var thread = await isar.threadModels.filter().addressEqualTo(normalized).findFirst();
      if (thread == null) {
        thread = ThreadModel()
          ..address = normalized
          ..senderName = senderName ?? address
          ..lastMessage = body
          ..timestamp = optimisticMessage.timestamp
          ..unreadCount = 0;
      } else {
        thread.lastMessage = body;
        thread.lastHasMedia = false;
        thread.timestamp = optimisticMessage.timestamp;
      }
      await isar.threadModels.put(thread);
    });

    // 2. Call Native API
    try {
      await _channel.invokeMethod('sendSms', {
        'address': normalized,
        'body': body,
        'deliveryReports': await deliveryReportsEnabled(),
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
