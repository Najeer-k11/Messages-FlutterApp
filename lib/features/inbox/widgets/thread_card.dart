import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';

class ThreadCard extends StatelessWidget {
  final ThreadModel thread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelecting;

  const ThreadCard({
    super.key,
    required this.thread,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelecting = false,
  });

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final hasUnread = thread.unreadCount > 0;

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
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  thread.senderName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  hasUnread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(hasUnread ? 'Mark as read' : 'Mark as unread'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final repo = context.read<SmsRepository>();
                  if (hasUnread) {
                    await repo.markThreadAsRead(thread.address, thread.nativeThreadId);
                  } else {
                    await repo.markThreadAsUnread(thread.address);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                title: const Text('Select'),
                onTap: () {
                  Navigator.pop(ctx);
                  onLongPress?.call();
                },
              ),
                ListTile(
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final inboxBloc = context.read<InboxBloc>();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete conversation?'),
                      content: Text(
                        'This will permanently delete all messages with ${thread.senderName}.',
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
                  if (confirmed == true) {
                    inboxBloc.add(DeleteThreadEvent(
                      address: thread.address,
                      nativeThreadId: thread.nativeThreadId,
                    ));
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

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localTime);
    if (diff.inDays == 0) {
      return "${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays == 1) {
      return "Yesterday";
    } else {
      return "${localTime.day}/${localTime.month}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasUnread = thread.unreadCount > 0;

    Widget card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: InkWell(
        onTap: onTap,
        onLongPress: isSelecting
            ? onLongPress // In selection mode: toggle select via parent
            : () => _showContextMenu(context), // Normal mode: show context menu
        borderRadius: BorderRadius.circular(24.0),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                )
              : null,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or checkbox
              if (isSelecting)
                _buildSelectionIndicator(theme)
              else
                _buildAvatar(theme, hasUnread),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'name_${thread.id}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                thread.senderName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(thread.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hasUnread
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      thread.lastMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasUnread
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Disable swipe-to-dismiss when in selection mode
    if (isSelecting) {
      return card;
    }

    return Dismissible(
      key: Key('thread_${thread.address}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete conversation?'),
                content: Text(
                  'This will permanently delete all messages with ${thread.senderName}.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        context.read<InboxBloc>().add(
          DeleteThreadEvent(
            address: thread.address,
            nativeThreadId: thread.nativeThreadId,
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24.0),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
          size: 28,
        ),
      ),
      child: card,
    );
  }

  Widget _buildSelectionIndicator(ThemeData theme) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: 2,
            ),
          ),
          child: isSelected
              ? Icon(Icons.check, size: 18, color: theme.colorScheme.onPrimary)
              : null,
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, bool hasUnread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Hero(
          tag: 'avatar_${thread.id}',
          child: CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              thread.senderName.isNotEmpty
                  ? thread.senderName.substring(0, 1).toUpperCase()
                  : '?',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        if (hasUnread)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
          ),
      ],
    );
  }
}
