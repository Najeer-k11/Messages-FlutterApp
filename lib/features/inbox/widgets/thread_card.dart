import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

String _initial(String name) => name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '?';

/// Contact avatar. A plain circle normally; unread conversations get the Cookie9 "moment" in
/// primary, and selection springs a check in on the same shape.
class ThreadAvatar extends StatelessWidget {
  const ThreadAvatar({
    super.key,
    required this.name,
    this.size = 52,
    this.unread = false,
    this.selecting = false,
    this.selected = false,
  });

  final String name;
  final double size;
  final bool unread;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (selecting) {
      return SizedBox.square(
        dimension: size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: selected
              ? SpringIn(
                  key: const ValueKey('on'),
                  child: ShapeBox(
                    size: size,
                    shape: CookieBorder.cookie9,
                    color: c.primary,
                    child: Icon(Icons.check_rounded, color: c.onPrimary, size: size * .5),
                  ),
                )
              : Container(
                  key: const ValueKey('off'),
                  decoration: ShapeDecoration(
                    shape: CircleBorder(side: BorderSide(color: c.outline, width: 2)),
                  ),
                  margin: EdgeInsets.all(size * .16),
                ),
        ),
      );
    }
    final style = (size >= 48 ? context.type.titleLargeEmphasized : context.type.titleMediumEmphasized);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: unread ? 1 : 0),
      duration: Motion.colour,
      builder: (context, t, _) => ShapeBox(
        size: size,
        shape: unread ? CookieBorder.cookie9 : Shapes.circle,
        color: Color.lerp(c.primaryContainer, c.primary, t)!,
        child: Text(_initial(name), style: style.copyWith(color: Color.lerp(c.onPrimaryContainer, c.onPrimary, t))),
      ),
    );
  }
}

class ThreadCard extends StatelessWidget {
  final ThreadModel thread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelecting;

  /// Swipe-to-delete. Off where deleting would be surprising (search results).
  final bool dismissible;

  const ThreadCard({
    super.key,
    required this.thread,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelecting = false,
    this.dismissible = true,
  });

  Future<bool> _confirmDelete(BuildContext context) => showConfirmDialog(
    context,
    title: 'Delete conversation?',
    message: 'This will permanently delete all messages with ${thread.senderName}.',
    confirmLabel: 'Delete',
  );

  void _showDetails(BuildContext context) {
    HapticFeedback.mediumImpact();
    final hasUnread = thread.unreadCount > 0;
    final repo = context.read<SmsRepository>();
    final inboxBloc = context.read<InboxBloc>();

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
                  _initial(thread.senderName),
                  style: ctx.type.titleLargeEmphasized.copyWith(color: ctx.colors.onPrimaryContainer),
                ),
              ),
              title: thread.senderName,
              subtitle: thread.senderName == thread.address ? null : thread.address,
            ),
            SheetGroup(
              children: [
                SheetActionRow(
                  icon: hasUnread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                  title: hasUnread ? 'Mark as read' : 'Mark as unread',
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (hasUnread) {
                      await repo.markThreadAsRead(thread.address, thread.nativeThreadId);
                    } else {
                      await repo.markThreadAsUnread(thread.address, thread.nativeThreadId);
                    }
                  },
                ),
                const SettingsDivider(),
                SheetActionRow(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Select',
                  subtitle: 'Pick several conversations at once',
                  onTap: () {
                    Navigator.pop(ctx);
                    onLongPress?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            BigActionButton(
              text: 'Delete conversation',
              icon: Icons.delete_outline_rounded,
              container: ctx.colors.errorContainer,
              content: ctx.colors.onErrorContainer,
              onTap: () async {
                Navigator.pop(ctx);
                if (await _confirmDelete(context)) {
                  inboxBloc.add(DeleteThreadEvent(address: thread.address, nativeThreadId: thread.nativeThreadId));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = today.difference(day).inDays;
    if (days == 0) {
      return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
    }
    if (days == 1) return 'Yesterday';
    return '${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasUnread = thread.unreadCount > 0;
    final tileColor = isSelected ? c.primaryContainer : context.groupContainer.withValues(alpha: .94);

    final card = LuminousElastic.tile(
      onTap: onTap,
      onLongPress: isSelecting ? onLongPress : () => _showDetails(context),
      child: AnimatedContainer(
        duration: Motion.colour,
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        decoration: ShapeDecoration(
          color: tileColor,
          shape: Shapes.tile.copyWith(
            side: BorderSide(
              color: isSelected ? c.primary.withValues(alpha: .5) : c.outlineVariant.withValues(alpha: .35),
              width: 1.25,
            ),
          ),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'avatar_${thread.id}',
              child: ThreadAvatar(
                name: thread.senderName,
                unread: hasUnread,
                selecting: isSelecting,
                selected: isSelected,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (hasUnread ? context.type.titleMediumEmphasized : context.text.titleMedium)?.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(thread.timestamp),
                        style: (hasUnread ? context.type.labelMediumEmphasized : context.text.labelMedium)?.copyWith(
                          color: hasUnread ? c.primary : c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _Preview(thread: thread, unread: hasUnread),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 10),
                        Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(shape: const StadiumBorder(), color: c.primary),
                          child: Text(
                            thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                            style: context.type.labelMediumEmphasized.copyWith(color: c.onPrimary, height: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final padded = Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: card);
    if (isSelecting || !dismissible) return padded;

    return Dismissible(
      key: Key('thread_${thread.address}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => context.read<InboxBloc>().add(
        DeleteThreadEvent(address: thread.address, nativeThreadId: thread.nativeThreadId),
      ),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: ShapeDecoration(shape: Shapes.tile, color: c.errorContainer),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline_rounded, color: c.onErrorContainer, size: 28),
      ),
      child: padded,
    );
  }
}

/// Last-message preview. Photo messages get a photo icon (and "Photo" when there is no caption)
/// rather than an emoji, so the glyph follows the theme colour and the type scale.
class _Preview extends StatelessWidget {
  const _Preview({required this.thread, required this.unread});

  final ThreadModel thread;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = unread ? c.onSurface : c.onSurfaceVariant;
    final style = (unread ? context.type.bodyMediumEmphasized : context.text.bodyMedium)?.copyWith(color: color);
    final text = thread.lastMessage.isNotEmpty ? thread.lastMessage : (thread.lastHasMedia ? 'Photo' : '');
    if (!thread.lastHasMedia) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
    }
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.photo_outlined, size: 18, color: color),
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
