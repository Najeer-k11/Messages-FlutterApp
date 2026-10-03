import 'package:flutter/material.dart';

class Composer extends StatefulWidget {
  final void Function(String text) onSend;
  final String? initialText;

  const Composer({
    super.key,
    required this.onSend,
    this.initialText,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  /// SMS character limits: 160 per segment for GSM-7, 153 for multi-part
  static const int _singleSmsLimit = 160;
  static const int _multipartSmsLimit = 153;

  String get _charCountLabel {
    final len = _controller.text.length;
    if (len == 0) return '';
    if (len <= _singleSmsLimit) {
      return '${_singleSmsLimit - len}';
    }
    // Multi-part
    final totalParts = ((len - _singleSmsLimit) / _multipartSmsLimit).ceil() + 1;
    final remaining = (totalParts * _multipartSmsLimit) - (len - _singleSmsLimit);
    return '$remaining/$totalParts';
  }

  bool get _showCharCount {
    final len = _controller.text.length;
    return len > 120; // Show counter when nearing the limit
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _controller.text = widget.initialText!;
      _hasText = widget.initialText!.isNotEmpty;
    }
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (_hasText != hasText) {
        setState(() => _hasText = hasText);
      } else {
        // Trigger rebuild for char counter
        if (_showCharCount || _controller.text.length > 100) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Attach',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Attachments coming soon'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                            ),
                          ),
                        ),
                        if (_showCharCount)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0, bottom: 14.0),
                            child: Text(
                              _charCountLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _controller.text.length > _singleSmsLimit
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _hasText
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _hasText
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: _hasText ? _handleSend : null,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
