import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:msgs/features/conversation/widgets/mms_image.dart';
import 'package:msgs/ui/ui.dart';

class MessageBubble extends StatefulWidget {
  final String messageText;
  final bool isMe;
  final DateTime timestamp;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// MMS media parts (`<uri>|<mime>`).
  final List<String> media;
  final bool pending;
  final bool failed;

  const MessageBubble({
    super.key,
    required this.messageText,
    required this.isMe,
    required this.timestamp,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.media = const [],
    this.pending = false,
    this.failed = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  double _dragOffset = 0;
  final List<TapGestureRecognizer> _recognizers = [];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _showDetectedSheet(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required List<({IconData icon, String title, VoidCallback onTap})> actions,
  }) {
    HapticFeedback.lightImpact();
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
                color: ctx.colors.tertiaryContainer,
                child: Icon(icon, color: ctx.colors.onTertiaryContainer),
              ),
              title: title,
              subtitle: value,
            ),
            SheetGroup(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SettingsDivider(),
                  SheetActionRow(
                    icon: actions[i].icon,
                    title: actions[i].title,
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      actions[i].onTap();
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkBottomSheet(BuildContext context, String url) {
    _showDetectedSheet(
      context,
      icon: Icons.link_rounded,
      title: 'Link',
      value: url,
      actions: [
        (
          icon: Icons.open_in_new_rounded,
          title: 'Open link',
          onTap: () async {
            final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
        ),
        (icon: Icons.copy_rounded, title: 'Copy link', onTap: () => Clipboard.setData(ClipboardData(text: url))),
      ],
    );
  }

  void _showPhoneBottomSheet(BuildContext context, String phone) {
    final digits = phone.replaceAll(RegExp(r'\s+|-'), '');
    _showDetectedSheet(
      context,
      icon: Icons.phone_rounded,
      title: 'Phone number',
      value: phone,
      actions: [
        (
          icon: Icons.call_outlined,
          title: 'Call',
          onTap: () async {
            try {
              await launchUrl(Uri.parse('tel:$digits'));
            } catch (_) {}
          },
        ),
        (
          icon: Icons.sms_outlined,
          title: 'Send message',
          onTap: () async {
            try {
              await launchUrl(Uri.parse('sms:$digits'));
            } catch (_) {}
          },
        ),
        (icon: Icons.copy_rounded, title: 'Copy number', onTap: () => Clipboard.setData(ClipboardData(text: phone))),
      ],
    );
  }

  List<InlineSpan> _buildMessageSpans(BuildContext context, String text, bool isMe, ThemeData theme) {
    final List<InlineSpan> spans = [];

    final urlRegex = RegExp(r'\b(?:https?://|www\.)\S+\b', caseSensitive: false);
    final phoneRegex = RegExp(r'\+?\b\d{10,12}\b|\+?\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b');

    // Find all matches
    final List<_TextMatch> matches = [];

    for (final match in urlRegex.allMatches(text)) {
      matches.add(_TextMatch(match.start, match.end, match.group(0)!, _MatchType.url));
    }

    for (final match in phoneRegex.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      final value = match.group(0)!;

      bool overlaps = false;
      for (final existing in matches) {
        if ((start >= existing.start && start < existing.end) || (end > existing.start && end <= existing.end)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        matches.add(_TextMatch(start, end, value, _MatchType.phone));
      }
    }

    // Sort matches by start index
    matches.sort((a, b) => a.start.compareTo(b.start));

    int lastIndex = 0;

    // Style for links/phone numbers
    final linkColor = isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary;

    final linkStyle = TextStyle(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
      fontWeight: FontWeight.normal,
      fontSize: theme.textTheme.bodyLarge!.fontSize,
    );

    for (final match in matches) {
      // Add normal text before the match
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      // Add match with tap recognizer
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (match.type == _MatchType.url) {
            _showLinkBottomSheet(context, match.value);
          } else {
            _showPhoneBottomSheet(context, match.value);
          }
        };
      _recognizers.add(recognizer);

      spans.add(TextSpan(text: match.value, style: linkStyle, recognizer: recognizer));

      lastIndex = match.end;
    }

    // Add remaining normal text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = widget.isMe;

    // Expressive grouping: the sender-side corners tighten to 8dp between bubbles of one group,
    // and the last bubble of a group gets a 4dp tail corner.
    const big = Radius.circular(24);
    final top = Radius.circular(widget.isFirstInGroup ? 24 : 8);
    final bottom = Radius.circular(widget.isLastInGroup ? 4 : 8);
    final borderRadius = BorderRadius.only(
      topLeft: isMe ? big : top,
      bottomLeft: isMe ? big : bottom,
      topRight: isMe ? top : big,
      bottomRight: isMe ? bottom : big,
    );

    // Clear old recognizers and generate new ones
    _clearRecognizers();
    final spans = _buildMessageSpans(context, widget.messageText, isMe, theme);

    final bubbleColor = isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh;

    final textStyle =
        theme.textTheme.bodyLarge?.copyWith(color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface) ??
        const TextStyle();

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            barrierColor: theme.colorScheme.scrim.withValues(alpha: 0.5),
            barrierDismissible: true,
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (context, animation, secondaryAnimation) {
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  children: [
                    // Dismiss barrier
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                    // Zoom Overlay
                    InstagramZoomOverlay(
                      messageText: widget.messageText,
                      isMe: isMe,
                      timestamp: widget.timestamp,
                      borderRadius: borderRadius,
                      backgroundColor: bubbleColor,
                      textStyle: textStyle,
                      messageSpans: spans,
                    ),
                  ],
                ),
              );
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final scaleAnimation = Tween<double>(
                begin: 0.85,
                end: 1.0,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
              final fadeAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOut);

              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8 * animation.value, sigmaY: 8 * animation.value),
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(scale: scaleAnimation, child: child),
                ),
              );
            },
          ),
        );
      },
      onHorizontalDragUpdate: (details) {
        // Elastic stretch physics for swipe-to-reply
        setState(() {
          _dragOffset += details.delta.dx;
          // Constrain drag and add friction
          if (isMe) {
            _dragOffset = _dragOffset.clamp(-80.0, 0.0);
          } else {
            _dragOffset = _dragOffset.clamp(0.0, 80.0);
          }
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset.abs() > 50) {
          // Trigger reply
        }
        // Spring back
        setState(() {
          _dragOffset = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(_dragOffset, 0, 0),
        margin: EdgeInsets.only(
          bottom: widget.isLastInGroup ? 10.0 : 3.0,
          left: isMe ? 48.0 : 0.0,
          right: isMe ? 0.0 : 48.0,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              for (final m in widget.media)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: GestureDetector(
                    onTap: () => showMmsImageViewer(context, m.split('|').first),
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: m.split('|').last.startsWith('image/')
                          ? MmsImage(uri: m.split('|').first, width: 240, height: 240, maxSide: 720)
                          : Container(
                              width: 200,
                              padding: const EdgeInsets.all(16),
                              color: bubbleColor,
                              child: Row(
                                children: [
                                  Icon(Icons.attachment_rounded, color: textStyle.color),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(m.split('|').last, style: textStyle)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              if (widget.messageText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: widget.failed ? theme.colorScheme.errorContainer : bubbleColor,
                    borderRadius: borderRadius,
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: spans,
                      style: widget.failed ? textStyle.copyWith(color: theme.colorScheme.onErrorContainer) : textStyle,
                    ),
                  ),
                ),
              if (widget.pending || widget.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.failed ? Icons.error_outline_rounded : Icons.schedule_rounded,
                        size: 14,
                        color: widget.failed ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.failed ? 'Not sent' : 'Sending…',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: widget.failed ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MatchType { url, phone }

class _TextMatch {
  final int start;
  final int end;
  final String value;
  final _MatchType type;

  _TextMatch(this.start, this.end, this.value, this.type);
}

class InstagramZoomOverlay extends StatelessWidget {
  final String messageText;
  final bool isMe;
  final DateTime timestamp;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final TextStyle textStyle;
  final List<InlineSpan> messageSpans;

  const InstagramZoomOverlay({
    super.key,
    required this.messageText,
    required this.isMe,
    required this.timestamp,
    required this.borderRadius,
    required this.backgroundColor,
    required this.textStyle,
    required this.messageSpans,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The zoomed message bubble
            Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: RichText(
                  text: TextSpan(
                    children: messageSpans.map((span) {
                      // Strip gesture recognizers in the overlay to prevent tap events firing on zoomed bubbles
                      if (span is TextSpan) {
                        return TextSpan(text: span.text, style: span.style);
                      }
                      return span;
                    }).toList(),
                    style: textStyle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Floating action pill.
            Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: theme.colorScheme.surfaceContainerHigh,
                  shadows: blueGlow(context),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OverlayAction(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(ClipboardData(text: messageText));
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 6),
                    _OverlayAction(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        SharePlus.instance.share(ShareParams(text: messageText));
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayAction extends StatelessWidget {
  const _OverlayAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LuminousElastic.small(
      shape: const StadiumBorder(),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 16, right: 20),
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: c.primaryContainer),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: c.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(label, style: context.type.labelLargeEmphasized.copyWith(color: c.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}
