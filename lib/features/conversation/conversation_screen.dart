import 'package:flutter/material.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/message_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/conversation/widgets/message_bubble.dart';
import 'package:msgs/features/conversation/widgets/composer.dart';
import 'package:msgs/core/motion/motion_engine.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class ConversationScreen extends StatefulWidget {
  final ThreadModel thread;
  final String? initialBody;

  const ConversationScreen({
    super.key,
    required this.thread,
    this.initialBody,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark thread as read as soon as conversation is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SmsRepository>().markThreadAsRead(
        widget.thread.address,
        widget.thread.nativeThreadId,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    try {
      await context.read<SmsRepository>().sendSms(widget.thread.address, text);

      // Scroll to bottom
      _scrollController.animateTo(
        0,
        duration: MotionEngine.durationFast,
        curve: MotionEngine.curveStandard,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send SMS: \$e')));
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

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
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

  void _showMoreOptions() {
    final theme = Theme.of(context);
    final isPhone = RegExp(r'^\+?[\d\s\-()]{7,}$').hasMatch(widget.thread.address);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (isPhone)
                ListTile(
                  leading: Icon(Icons.person_add_outlined, color: theme.colorScheme.primary),
                  title: const Text('Add to contacts'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse('tel:${widget.thread.address}');
                    try {
                      await launchUrl(uri);
                    } catch (_) {}
                  },
                ),
              if (isPhone)
                ListTile(
                  leading: Icon(Icons.copy, color: theme.colorScheme.primary),
                  title: const Text('Copy number'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: widget.thread.address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Number copied')),
                    );
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text(
                  'Delete conversation',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete conversation?'),
                      content: Text(
                        'This will permanently delete all messages with ${widget.thread.senderName}.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await context.read<SmsRepository>().deleteThread(
                      widget.thread.address,
                      widget.thread.nativeThreadId,
                    );
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.thread.id}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  widget.thread.senderName.isNotEmpty
                      ? widget.thread.senderName.substring(0, 1).toUpperCase()
                      : '?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Hero(
                tag: 'name_${widget.thread.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    widget.thread.senderName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () async {
              await launchUrl(Uri.parse('tel:${widget.thread.address}'));
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Dynamic Background using subtle theme gradients
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  initialData: context.read<SmsRepository>().getMessagesForThreadSync(
                    widget.thread.address,
                  ),
                  stream: context.read<SmsRepository>().watchMessagesForThread(
                    widget.thread.address,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: \${snapshot.error}'));
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
                      final showSeparator = isLastMessage ||
                          (nextMessage != null &&
                              !_isSameDay(message.timestamp, nextMessage.timestamp));
                      if (showSeparator) {
                        items.add(_ConversationItem.separator(message.timestamp));
                      }
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Latest messages at the bottom
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        );
                      },
                    );
                  },
                ),
              ),
              Composer(onSend: _sendMessage, initialText: widget.initialBody),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(ThemeData theme, DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          const Expanded(child: Divider(indent: 16, endIndent: 8)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDateSeparator(timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 8, endIndent: 16)),
        ],
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

  const _ConversationItem._({
    this.message,
    this.timestamp,
    this.messageIndex,
    required this.isSeparator,
  });

  factory _ConversationItem.message(MessageModel msg, int index) =>
      _ConversationItem._(message: msg, messageIndex: index, isSeparator: false);

  factory _ConversationItem.separator(DateTime ts) =>
      _ConversationItem._(timestamp: ts, isSeparator: true);
}
