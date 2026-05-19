import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends StatefulWidget {
  final String messageText;
  final bool isMe;
  final DateTime timestamp;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const MessageBubble({
    super.key,
    required this.messageText,
    required this.isMe,
    required this.timestamp,
    required this.isFirstInGroup,
    required this.isLastInGroup,
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

  void _showLinkBottomSheet(BuildContext context, String url) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link Detected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  url,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Icon(
                    Icons.open_in_new,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Open Link'),
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    final uri = Uri.parse(
                      url.startsWith('http') ? url : 'https://$url',
                    );
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  },
                ),
                ListTile(
                  leading: Icon(Icons.copy, color: theme.colorScheme.primary),
                  title: const Text('Copy Link'),
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: url));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPhoneBottomSheet(BuildContext context, String phone) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone Number Detected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phone,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Icon(Icons.phone, color: theme.colorScheme.primary),
                  title: const Text('Call'),
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    final uri = Uri.parse(
                      'tel:${phone.replaceAll(RegExp(r'\s+|-'), '')}',
                    );
                    try {
                      await launchUrl(uri);
                    } catch (_) {}
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.message,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Send Message'),
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    final uri = Uri.parse(
                      'sms:${phone.replaceAll(RegExp(r'\s+|-'), '')}',
                    );
                    try {
                      await launchUrl(uri);
                    } catch (_) {}
                  },
                ),
                ListTile(
                  leading: Icon(Icons.copy, color: theme.colorScheme.primary),
                  title: const Text('Copy Number'),
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: phone));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<InlineSpan> _buildMessageSpans(
    BuildContext context,
    String text,
    bool isMe,
    ThemeData theme,
  ) {
    final List<InlineSpan> spans = [];

    final urlRegex = RegExp(
      r'\b(?:https?://|www\.)\S+\b',
      caseSensitive: false,
    );
    final phoneRegex = RegExp(
      r'\+?\b\d{10,12}\b|\+?\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b',
    );

    // Find all matches
    final List<_TextMatch> matches = [];

    for (final match in urlRegex.allMatches(text)) {
      matches.add(
        _TextMatch(match.start, match.end, match.group(0)!, _MatchType.url),
      );
    }

    for (final match in phoneRegex.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      final value = match.group(0)!;

      bool overlaps = false;
      for (final existing in matches) {
        if ((start >= existing.start && start < existing.end) ||
            (end > existing.start && end <= existing.end)) {
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
    final linkColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;

    final linkStyle = TextStyle(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
      fontWeight: FontWeight.normal,
      fontSize: theme.textTheme.bodyMedium!.fontSize,
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

      spans.add(
        TextSpan(text: match.value, style: linkStyle, recognizer: recognizer),
      );

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

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(!isMe && widget.isLastInGroup ? 4 : 20),
      bottomRight: Radius.circular(isMe && widget.isLastInGroup ? 4 : 20),
    );

    // Clear old recognizers and generate new ones
    _clearRecognizers();
    final spans = _buildMessageSpans(context, widget.messageText, isMe, theme);

    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;

    final textStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: isMe
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ) ??
        const TextStyle();

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black.withValues(alpha: 0.6),
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0)
                      .animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      );
                  final fadeAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  );

                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 8 * animation.value,
                      sigmaY: 8 * animation.value,
                    ),
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: ScaleTransition(
                        scale: scaleAnimation,
                        child: child,
                      ),
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
          bottom: widget.isLastInGroup ? 8.0 : 2.0,
          left: isMe ? 40.0 : 8.0,
          right: isMe ? 8.0 : 40.0,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              boxShadow: widget.isLastInGroup
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: RichText(
              text: TextSpan(children: spans, style: textStyle),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
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
            // Floating action pill matching the bubble background color
            Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Copy Button
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: messageText));
                          Navigator.pop(context);
                        },
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.copy,
                                size: 18,
                                color: isMe
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Copy',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isMe
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Divider
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.2)
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                      ),
                      // Share Button
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Share.share(messageText);
                          Navigator.pop(context);
                        },
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.share,
                                size: 18,
                                color: isMe
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Share',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isMe
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
