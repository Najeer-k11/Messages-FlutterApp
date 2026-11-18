import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/thread_prefs_model.dart';
import 'package:msgs/features/inbox/thread_actions.dart';
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

  /// This conversation's settings (pinned, muted, draft…), if it has any.
  final ThreadPrefsModel? prefs;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelecting;

  /// Swipe actions (archive one way, delete the other). Off where they would be surprising
  /// (search results).
  final bool dismissible;

  /// Snackbars sit above the floating dock (inbox) rather than at the screen edge.
  final bool snackAboveDock;

  const ThreadCard({
    super.key,
    required this.thread,
    this.prefs,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelecting = false,
    this.dismissible = true,
    this.snackAboveDock = false,
  });

  bool get _pinned => prefs?.pinned ?? false;
  bool get _archived => prefs?.archived ?? false;
  bool get _muted => prefs?.muted ?? false;
  bool get _spam => prefs?.spam ?? false;

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
    final addresses = [thread.address];

    showExpressiveSheet<void>(
      context,
      builder: (ctx) {
        void run(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        return Padding(
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
                  if (!_spam && !_archived) ...[
                    SheetActionRow(
                      icon: _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      title: _pinned ? 'Unpin' : 'Pin to top',
                      onTap: () => run(() => repo.setPinned(addresses, !_pinned)),
                    ),
                    const SettingsDivider(),
                  ],
                  SheetActionRow(
                    icon: hasUnread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                    title: hasUnread ? 'Mark as read' : 'Mark as unread',
                    onTap: () => run(() {
                      hasUnread
                          ? repo.markThreadAsRead(thread.address, thread.nativeThreadId)
                          : repo.markThreadAsUnread(thread.address, thread.nativeThreadId);
                    }),
                  ),
                  const SettingsDivider(),
                  SheetActionRow(
                    icon: _muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                    title: _muted ? 'Unmute' : 'Mute',
                    subtitle: _muted ? null : 'No notifications from this conversation',
                    onTap: () => run(() => setThreadsMuted(context, addresses, !_muted, aboveDock: snackAboveDock)),
                  ),
                  if (!_spam) ...[
                    const SettingsDivider(),
                    SheetActionRow(
                      icon: _archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                      title: _archived ? 'Unarchive' : 'Archive',
                      onTap: () => run(() => setThreadsArchived(context, addresses, !_archived, aboveDock: snackAboveDock)),
                    ),
                  ],
                  const SettingsDivider(),
                  SheetActionRow(
                    icon: _spam ? Icons.report_off_outlined : Icons.report_outlined,
                    title: _spam ? 'Not spam' : 'Report spam',
                    subtitle: _spam ? 'Move back to your inbox' : 'Move to Spam and stop notifications',
                    onTap: () => run(() => setThreadsSpam(context, addresses, !_spam, aboveDock: snackAboveDock)),
                  ),
                  if (onLongPress != null) ...[
                    const SettingsDivider(),
                    SheetActionRow(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Select',
                      subtitle: 'Pick several conversations at once',
                      onTap: () => run(onLongPress!),
                    ),
                  ],
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
        );
      },
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
    final draft = prefs?.draft ?? '';

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
                      if (_muted) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.notifications_off_outlined, size: 16, color: c.onSurfaceVariant, semanticLabel: 'Muted'),
                      ],
                      if (_pinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin_rounded, size: 16, color: c.primary, semanticLabel: 'Pinned'),
                      ],
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
                        child: draft.isNotEmpty
                            ? Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Draft: ',
                                      style: context.type.bodyMediumEmphasized.copyWith(color: c.error),
                                    ),
                                    TextSpan(text: draft.replaceAll('\n', ' ')),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                              )
                            : _Preview(thread: thread, unread: hasUnread),
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

    // Swipe right: archive (unarchive in Archived, "not spam" in Spam). Swipe left: delete.
    final (IconData swipeIcon, String swipeLabel) = _spam
        ? (Icons.report_off_outlined, 'Not spam')
        : _archived
        ? (Icons.unarchive_outlined, 'Unarchive')
        : (Icons.archive_outlined, 'Archive');

    return Dismissible(
      key: Key('thread_${thread.address}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) return _confirmDelete(context);
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          context.read<InboxBloc>().add(DeleteThreadEvent(address: thread.address, nativeThreadId: thread.nativeThreadId));
        } else if (_spam) {
          setThreadsSpam(context, [thread.address], false, aboveDock: snackAboveDock);
        } else {
          setThreadsArchived(context, [thread.address], !_archived, aboveDock: snackAboveDock);
        }
      },
      background: _SwipeBackground(
        icon: swipeIcon,
        label: swipeLabel,
        alignment: Alignment.centerLeft,
        color: c.tertiaryContainer,
        content: c.onTertiaryContainer,
      ),
      secondaryBackground: _SwipeBackground(
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        alignment: Alignment.centerRight,
        color: c.errorContainer,
        content: c.onErrorContainer,
      ),
      child: padded,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.alignment,
    required this.color,
    required this.content,
  });

  final IconData icon;
  final String label;
  final Alignment alignment;
  final Color color;
  final Color content;

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, color: content, size: 26),
      const SizedBox(width: 10),
      Text(label, style: context.type.labelLargeEmphasized.copyWith(color: content)),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: ShapeDecoration(shape: Shapes.tile, color: color),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft ? children : children.reversed.toList(),
      ),
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
