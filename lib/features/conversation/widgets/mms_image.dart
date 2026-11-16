import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

/// Shows an image from a content Uri (picked attachment or MMS part). Bytes are decoded and
/// downscaled natively, then kept in a small LRU cache so scrolling a conversation doesn't
/// re-read the provider.
class MmsImage extends StatefulWidget {
  const MmsImage({super.key, required this.uri, this.width, this.height, this.maxSide = 1080, this.fit = BoxFit.cover});

  final String uri;
  final double? width;
  final double? height;
  final int maxSide;
  final BoxFit fit;

  @override
  State<MmsImage> createState() => _MmsImageState();
}

class _MmsImageState extends State<MmsImage> {
  static final _cache = <String, Uint8List>{};
  static const _cacheLimit = 40;

  Future<Uint8List?>? _future;

  String get _key => '${widget.uri}@${widget.maxSide}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MmsImage old) {
    super.didUpdateWidget(old);
    if (old.uri != widget.uri || old.maxSide != widget.maxSide) _load();
  }

  void _load() {
    final cached = _cache.remove(_key);
    if (cached != null) {
      _cache[_key] = cached; // most recently used
      _future = SynchronousFuture(cached);
      return;
    }
    final key = _key;
    _future = context
        .read<SmsRepository>()
        .readMedia(widget.uri, maxSide: widget.maxSide)
        .then((bytes) {
          if (bytes != null) {
            _cache[key] = bytes;
            while (_cache.length > _cacheLimit) {
              _cache.remove(_cache.keys.first);
            }
          }
          return bytes;
        })
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            return Image.memory(snap.data!, fit: widget.fit, gaplessPlayback: true);
          }
          final failed = snap.connectionState == ConnectionState.done;
          return ColoredBox(
            color: c.surfaceContainerHighest,
            child: Center(
              child: failed
                  ? Icon(Icons.broken_image_outlined, color: c.onSurfaceVariant)
                  : const ExpressiveLoadingIndicator(size: 28),
            ),
          );
        },
      ),
    );
  }
}

/// Full-screen viewer for an MMS image, with pinch-zoom.
void showMmsImageViewer(BuildContext context, String uri) {
  Navigator.push(
    context,
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Material(
          color: Colors.black,
          child: SafeArea(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: MmsImage(uri: uri, maxSide: 2048, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
      transitionsBuilder: (context, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}
