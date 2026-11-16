import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/message_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/conversation/widgets/message_bubble.dart';
import 'package:msgs/features/conversation/widgets/composer.dart';
import 'package:msgs/features/inbox/widgets/thread_card.dart' show ThreadAvatar;
import 'package:msgs/ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class ConversationScreen extends StatefulWidget {
  final ThreadModel thread;
  final String? initialBody;

  const ConversationScreen({super.key, required this.thread, this.initialBody});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<bool>? _mmsResults;
  StreamSubscription<List<MessageModel>>? _incoming;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    // MMS completes asynchronously in the platform MMS service; surface failures here.
    _mmsResults = context.read<SmsRepository>().mmsSendResults.listen((ok) {
      if (!ok && mounted) showExpressiveSnack(context, 'Photo message couldn’t be sent');
    });
    // Mark the thread read when opened, and again whenever a message arrives while it is on
    // screen; otherwise those arrivals stayed unread and the thread showed up as unread later.
    final repo = context.read<SmsRepository>();
    _incoming = repo.watchMessagesForThread(widget.thread.address).listen((messages) {
      final visible = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (visible && messages.any((m) => !m.isMe && !m.isRead)) _markRead();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    if (_marking || !mounted) return;
    _marking = true;
    try {
      await context.read<SmsRepository>().markThreadAsRead(widget.thread.address, widget.thread.nativeThreadId);
    } finally {
      _marking = false;
    }
  }

  @override
  void dispose() {
    _mmsResults?.cancel();
    _incoming?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, List<String> attachments) async {
    try {
      final repo = context.read<SmsRepository>();
      if (attachments.isNotEmpty) {
        await repo.sendMms(widget.thread.address, text, attachments);
      } else {
        await repo.sendSms(widget.thread.address, text);
      }

      // Scroll to bottom
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } catch (e) {
      if (mounted) {
        showExpressiveSnack(context, 'Couldn’t send: $e');
      }
    }
  }

  /// Returns a label like "Today", "Yesterday", or "Mon, Oct 2" for date separators.
  String _formatDateSeparator(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[(local.weekday - 1) % 7];
    final monthName = months[local.month - 1];
    // Show year if different year
    if (local.year != now.year) {
      return '$dayName, $monthName ${local.day}, ${local.year}';
    }
    return '$dayName, $monthName ${local.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  bool get _isPhone => RegExp(r'^\+?[\d\s\-()]{7,}$').hasMatch(widget.thread.address);

  Future<void> _showMoreOptions() async {
    final thread = widget.thread;
    final repo = context.read<SmsRepository>();
    // A saved number gets "View contact" instead of "Add to contacts".
    final contactUri = _isPhone ? await repo.findContact(thread.address) : null;
    if (!mounted) return;
    showExpressiveSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailsHeader(
              badge: ShapeBox(
                size: 52,
                shape: CookieBorder.cookie7,
                color: ctx.colors.primaryContainer,
                child: Text(
                  thread.senderName.trim().isNotEmpty ? thread.senderName.trim()[0].toUpperCase() : '?',
                  style: ctx.type.titleLargeEmphasized.copyWith(color: ctx.colors.onPrimaryContainer),
                ),
              ),
              title: thread.senderName,
              subtitle: thread.senderName == thread.address ? null : thread.address,
            ),
            if (_isPhone) ...[
              SheetGroup(
                children: [
                  if (contactUri != null)
                    SheetActionRow(
                      icon: Icons.person_outline_rounded,
                      title: 'View contact',
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await repo.openContact(contactUri);
                        } catch (_) {
                          if (mounted) showExpressiveSnack(context, 'Couldn’t open Contacts');
                        }
                      },
                    )
                  else
                    SheetActionRow(
                      icon: Icons.person_add_outlined,
                      title: 'Add to contacts',
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await repo.addContact(thread.address);
                        } catch (_) {
                          if (mounted) showExpressiveSnack(context, 'Couldn’t open Contacts');
                        }
                      },
                    ),
                  const SettingsDivider(),
                  SheetActionRow(
                    icon: Icons.copy_rounded,
                    title: 'Copy number',
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: thread.address));
                      showExpressiveSnack(context, 'Number copied');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            BigActionButton(
              text: 'Delete conversation',
              icon: Icons.delete_outline_rounded,
              container: ctx.colors.errorContainer,
              content: ctx.colors.onErrorContainer,
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete conversation?',
                  message: 'This will permanently delete all messages with ${thread.senderName}.',
                  confirmLabel: 'Delete',
                );
                if (confirmed && mounted) {
                  await context.read<SmsRepository>().deleteThread(thread.address, thread.nativeThreadId);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thread = widget.thread;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.surface,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                RoundTonalButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  size: 52,
                  onTap: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 12),
                Hero(
                  tag: 'avatar_${thread.id}',
                  child: ThreadAvatar(name: thread.senderName, size: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.titleLargeEmphasized.copyWith(color: c.onSurface),
                      ),
                      if (thread.senderName != thread.address)
                        Text(
                          thread.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (_isPhone) ...[
                  RoundTonalButton(
                    icon: Icons.call_outlined,
                    label: 'Call',
                    onTap: () => launchUrl(Uri.parse('tel:${thread.address}')),
                  ),
                  const SizedBox(width: 8),
                ],
                RoundTonalButton(
                  icon: Icons.more_horiz_rounded,
                  label: 'More options',
                  container: c.surfaceContainerHigh,
                  content: c.onSurface,
                  onTap: _showMoreOptions,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              initialData: context.read<SmsRepository>().getMessagesForThreadSync(widget.thread.address),
              stream: context.read<SmsRepository>().watchMessagesForThread(widget.thread.address),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: ExpressiveLoadingIndicator(contained: true));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messagesList = snapshot.data ?? [];

                // Build list items with date separators
                // messagesList is reverse-sorted (newest first, for reverse ListView)
                final List<_ConversationItem> items = [];

                for (int i = 0; i < messagesList.length; i++) {
                  final message = messagesList[i];
                  items.add(_ConversationItem.message(message, i));

                  // Show date separator AFTER the message in the items list
                  // (which appears BEFORE it visually since ListView is reversed)
                  final isLastMessage = i == messagesList.length - 1;
                  final nextMessage = isLastMessage ? null : messagesList[i + 1];
                  final showSeparator =
                      isLastMessage || (nextMessage != null && !_isSameDay(message.timestamp, nextMessage.timestamp));
                  if (showSeparator) {
                    items.add(_ConversationItem.separator(message.timestamp));
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Latest messages at the bottom
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    if (item.isSeparator) {
                      return _buildDateSeparator(theme, item.timestamp!);
                    }

                    final message = item.message!;
                    final msgIndex = item.messageIndex!;

                    // Logic for grouping bubbles
                    bool isFirstInGroup = true;
                    bool isLastInGroup = true;

                    if (msgIndex > 0) {
                      final prevMessage = messagesList[msgIndex - 1];
                      if (prevMessage.isMe == message.isMe) {
                        isLastInGroup = false;
                      }
                    }
                    if (msgIndex < messagesList.length - 1) {
                      final nextMessage = messagesList[msgIndex + 1];
                      if (nextMessage.isMe == message.isMe) {
                        isFirstInGroup = false;
                      }
                    }

                    return MessageBubble(
                      messageText: message.body,
                      isMe: message.isMe,
                      timestamp: message.timestamp,
                      isFirstInGroup: isFirstInGroup,
                      isLastInGroup: isLastInGroup,
                      media: message.media,
                      pending: message.pending,
                      failed: message.failed,
                    );
                  },
                );
              },
            ),
          ),
          Composer(onSend: _sendMessage, initialText: widget.initialBody),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(ThemeData theme, DateTime timestamp) {
    final label = _formatDateSeparator(timestamp);
    final today = label == 'Today';
    final c = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: ShapeDecoration(shape: Shapes.pill, color: today ? c.primaryContainer : c.surfaceContainerHigh),
          child: Text(
            label,
            style: context.type.labelLargeEmphasized.copyWith(color: today ? c.onPrimaryContainer : c.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// A discriminated union for list items in the conversation (message or date separator).
class _ConversationItem {
  final MessageModel? message;
  final DateTime? timestamp;
  final int? messageIndex;
  final bool isSeparator;

  const _ConversationItem._({this.message, this.timestamp, this.messageIndex, required this.isSeparator});

  factory _ConversationItem.message(MessageModel msg, int index) =>
      _ConversationItem._(message: msg, messageIndex: index, isSeparator: false);

  factory _ConversationItem.separator(DateTime ts) => _ConversationItem._(timestamp: ts, isSeparator: true);
}
