import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgs/features/conversation/widgets/mms_image.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

class Composer extends StatefulWidget {
  /// [attachments] are content Uris; non-empty means the message goes as MMS.
  final void Function(String text, List<String> attachments) onSend;
  final String? initialText;

  const Composer({super.key, required this.onSend, this.initialText});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  final List<String> _attachments = [];

  bool get _canSend => _hasText || _attachments.isNotEmpty;

  Future<void> _attach() async {
    try {
      final picked = await context.read<SmsRepository>().pickMedia();
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _attachments.addAll(picked.where((u) => !_attachments.contains(u)));
        if (_attachments.length > 3) _attachments.removeRange(3, _attachments.length);
      });
    } on PlatformException catch (e) {
      if (mounted) showExpressiveSnack(context, 'Couldn’t open photos: ${e.message}');
    }
  }

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
    if (text.isEmpty && _attachments.isEmpty) return;
    widget.onSend(text, List.of(_attachments));
    _controller.clear();
    setState(_attachments.clear);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // MMS has no 160-character segmenting, so the counter only matters for plain SMS.
    final over = _attachments.isEmpty && _controller.text.length > _singleSmsLimit;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                decoration: ShapeDecoration(shape: Shapes.cta, color: c.surfaceContainerHigh),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: _attachments.isEmpty
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
                              child: SizedBox(
                                height: 84,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _attachments.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, i) => _AttachmentChip(
                                    uri: _attachments[i],
                                    onRemove: () => setState(() => _attachments.removeAt(i)),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RoundTonalButton(
                          icon: Icons.add_photo_alternate_outlined,
                          label: 'Attach photo',
                          size: 44,
                          container: c.surfaceContainerHighest,
                          content: c.onSurfaceVariant,
                          onTap: _attachments.length >= 3 ? null : _attach,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 6,
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              style: context.text.bodyLarge?.copyWith(color: c.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Text message',
                                hintStyle: context.text.bodyLarge?.copyWith(
                                  color: c.onSurfaceVariant.withValues(alpha: .6),
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                        ),
                        if (_showCharCount && _attachments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 12),
                            child: Text(
                              _charCountLabel,
                              style: context.type.labelMediumEmphasized.copyWith(
                                color: over ? c.error : c.onSurfaceVariant,
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
            // Send: springs up and fills with primary once there is something to send.
            SpringBuilder(
              value: _canSend ? 1 : .88,
              spring: Motion.pillAppear,
              builder: (context, s, child) => Transform.scale(scale: s, child: child),
              child: LuminousElastic(
                enabled: _canSend,
                onTap: _canSend ? _handleSend : null,
                semanticLabel: 'Send',
                child: AnimatedContainer(
                  duration: Motion.colour,
                  width: 56,
                  height: 56,
                  decoration: ShapeDecoration(
                    shape: _canSend ? CookieBorder.cookie9 : Shapes.circle,
                    color: _canSend ? c.primary : c.surfaceContainerHigh,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _canSend ? c.onPrimary : c.onSurfaceVariant.withValues(alpha: .6),
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

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.uri, required this.onRemove});

  final String uri;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: MmsImage(uri: uri, width: 84, height: 84, maxSide: 256, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: RoundTonalButton(
            icon: Icons.close_rounded,
            label: 'Remove photo',
            size: 28,
            container: c.inverseSurface.withValues(alpha: .8),
            content: c.onInverseSurface,
            onTap: onRemove,
          ),
        ),
      ],
    );
  }
}
