import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/physics.dart';

import 'motion.dart';
import 'theme/expressive_theme.dart';

/// A restrained glass surface: diagonal gradient of [tint], a bright 1.25dp edge and a soft,
/// primary-tinted shadow. Pair with [blueGlow] for floating controls.
ShapeDecoration glassDecoration(
  BuildContext context, {
  required ShapeBorder shape,
  required Color tint,
  double borderAlpha = .82,
  double shadowElevation = 14,
  bool glow = false,
}) {
  final dark = tint.computeLuminance() < .5;
  final accent = context.colors.primary;
  final a = tint.a;
  final border = Colors.white.withValues(alpha: dark ? .14 : borderAlpha);
  final outline = shape is OutlinedBorder ? shape.copyWith(side: BorderSide(color: border, width: 1.25)) : shape;
  return ShapeDecoration(
    shape: outline,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [tint.withValues(alpha: a * .94 / .88), tint.withValues(alpha: a), tint.withValues(alpha: a * .84 / .88)]
          : [tint.withValues(alpha: a * .96 / .88), tint.withValues(alpha: a), tint.withValues(alpha: a * .82 / .88)],
    ),
    shadows: [
      if (shadowElevation > 0) ...[
        BoxShadow(
          color: dark ? Colors.black.withValues(alpha: .45) : accent.withValues(alpha: .10),
          blurRadius: shadowElevation,
          offset: Offset(0, shadowElevation * .3),
        ),
        BoxShadow(
          color: dark ? Colors.black.withValues(alpha: .35) : accent.withValues(alpha: .14),
          blurRadius: shadowElevation * 2,
          offset: Offset(0, shadowElevation * .6),
        ),
      ],
      if (glow) ...blueGlow(context),
    ],
  );
}

/// The small theme-coloured drop shadow beneath floating controls.
List<BoxShadow> blueGlow(BuildContext context, {Color? color}) {
  final c = color ?? context.colors.primary;
  return [BoxShadow(color: c.withValues(alpha: .16), blurRadius: 34, offset: const Offset(0, 12))];
}

/// The press feedback for every tappable surface, replacing the default ripple:
/// scale to .95, one-sided directional stretch toward the finger, a finger-following luminous
/// bloom, a ripple from the touch point, and an under-damped spring on release.
class LuminousElastic extends StatefulWidget {
  const LuminousElastic({
    super.key,
    required this.child,
    this.shape = const CircleBorder(),
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.maxStretch = 0.092,
    this.maxTranslate = 2.6,
    this.bloomScale = 1.0,
    this.semanticLabel,
  });

  /// Compact preset for small round controls.
  const LuminousElastic.small({
    super.key,
    required this.child,
    this.shape = const CircleBorder(),
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
  }) : maxStretch = 0.092,
       maxTranslate = 2.6,
       bloomScale = 1.0;

  /// Preset for large tiles: barely stretches, so text stays readable.
  const LuminousElastic.tile({
    super.key,
    required this.child,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
  }) : maxStretch = 0.03,
       maxTranslate = 1.2,
       bloomScale = 1.0;

  final Widget child;
  final ShapeBorder shape;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double maxStretch;
  final double maxTranslate;
  final double bloomScale;
  final String? semanticLabel;

  @override
  State<LuminousElastic> createState() => _LuminousElasticState();
}

class _LuminousElasticState extends State<LuminousElastic> with TickerProviderStateMixin {
  static final _pressSpring = Motion.spring(0.82, 550);
  static final _scaleRelease = Motion.spring(0.62, 420);

  late final _dx = AnimationController.unbounded(vsync: this);
  late final _dy = AnimationController.unbounded(vsync: this);
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  late final _lum = AnimationController(vsync: this);
  late final _ripple = AnimationController(vsync: this, value: 1, duration: const Duration(milliseconds: 420));
  late final Listenable _all = Listenable.merge([_dx, _dy, _scale, _lum, _ripple]);

  Offset? _touch;
  Offset? _lastTouch;
  Offset? _down;
  Offset? _rippleOrigin;
  bool _pressed = false;

  @override
  void dispose() {
    for (final c in [_dx, _dy, _scale, _lum, _ripple]) {
      c.dispose();
    }
    super.dispose();
  }

  void _springTo(AnimationController c, double target, SpringDescription s) =>
      c.animateWith(SpringSimulation(s, c.value, target, c.velocity));

  void _onDown(PointerDownEvent e) {
    if (!widget.enabled) return;
    _down = e.localPosition;
    _rippleOrigin = e.localPosition;
    _ripple
      ..value = 0
      ..animateTo(1, curve: Curves.fastOutSlowIn);
    _pressed = true;
    _scale.animateTo(.95, duration: const Duration(milliseconds: 90), curve: Curves.fastOutSlowIn);
    _lum.animateTo(1, duration: const Duration(milliseconds: 120), curve: Curves.fastOutSlowIn);
    _track(e.localPosition);
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pressed) return;
    // A drag (list scroll, sheet swipe) is not a press: let go so scrolling content doesn't wobble.
    if ((e.localPosition - _down!).distance > kTouchSlop) {
      _release();
      return;
    }
    _track(e.localPosition);
  }

  void _track(Offset pos) {
    final box = context.size;
    if (box == null || box.isEmpty) return;
    _touch = pos;
    _lastTouch = pos;
    final cx = box.width / 2, cy = box.height / 2;
    _springTo(_dx, ((pos.dx - cx) / cx).clamp(-1.0, 1.0), _pressSpring);
    _springTo(_dy, ((pos.dy - cy) / cy).clamp(-1.0, 1.0), _pressSpring);
  }

  void _release() {
    if (!_pressed) return;
    _pressed = false;
    _touch = null;
    _springTo(_dx, 0, Motion.pressRelease);
    _springTo(_dy, 0, Motion.pressRelease);
    _springTo(_scale, 1, _scaleRelease);
    _lum.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.fastOutSlowIn);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isAppDark;
    final primary = context.colors.primary;
    final interactive = widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    Widget content = AnimatedBuilder(
      animation: _all,
      child: widget.child,
      builder: (context, child) {
        final dx = _dx.value, dy = _dy.value, s = _scale.value;
        final sx = s * (1 + widget.maxStretch * dx.abs() - 0.03 * dy.abs());
        final sy = s * (1 + widget.maxStretch * 1.06 * dy.abs() - 0.03 * dx.abs());
        // Pivot on the side away from the finger, so the stretch is one-sided.
        final px = (0.5 - 0.30 * dx).clamp(0.15, 0.85);
        final py = (0.5 - 0.30 * dy).clamp(0.15, 0.85);
        final m = Matrix4.translationValues(dx * widget.maxTranslate, dy * widget.maxTranslate, 0)
          ..multiply(Matrix4.diagonal3Values(sx, sy, 1));
        return Transform(
          transform: m,
          alignment: Alignment(px * 2 - 1, py * 2 - 1),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: widget.shape, textDirection: Directionality.of(context)),
            child: CustomPaint(
              foregroundPainter: _BloomPainter(
                shape: widget.shape,
                dark: dark,
                primary: primary,
                lum: _lum.value,
                touch: _touch ?? _lastTouch,
                rippleOrigin: _rippleOrigin,
                ripple: _ripple.value,
                pressed: _pressed,
                bloomScale: widget.bloomScale,
              ),
              child: child,
            ),
          ),
        );
      },
    );

    if (interactive) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: content,
      );
    }

    return Semantics(
      button: interactive,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: content,
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  _BloomPainter({
    required this.shape,
    required this.dark,
    required this.primary,
    required this.lum,
    required this.touch,
    required this.rippleOrigin,
    required this.ripple,
    required this.pressed,
    required this.bloomScale,
  });

  final ShapeBorder shape;
  final bool dark;
  final Color primary;
  final double lum;
  final Offset? touch;
  final Offset? rippleOrigin;
  final double ripple;
  final bool pressed;
  final double bloomScale;

  static const _darkOuter = Color(0xFF80D8FF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);
    final center = touch ?? size.center(Offset.zero);
    final centerColor = dark ? Colors.white.withValues(alpha: .48 * lum) : primary.withValues(alpha: .28 * lum);
    final outerColor = dark ? _darkOuter.withValues(alpha: .22 * lum) : primary.withValues(alpha: .11 * lum);

    if (lum > .01) {
      final radius = (dark ? size.longestSide * .75 : size.shortestSide * 1.15 + size.longestSide * .22) * bloomScale;
      final shader = dark
          ? RadialGradient(colors: [centerColor, outerColor, Colors.transparent])
          : RadialGradient(
              colors: [
                centerColor,
                primary.withValues(alpha: .15 * lum),
                outerColor.withValues(alpha: .04 * lum),
                Colors.transparent,
              ],
              stops: const [0, .38, .72, 1],
            );
      canvas.drawPath(path, Paint()..shader = shader.createShader(Rect.fromCircle(center: center, radius: radius)));
    }

    final rippleAlpha = (1 - ripple) * (pressed ? 1 : lum);
    if (ripple < 1 && rippleAlpha > .01 && rippleOrigin != null) {
      final origin = Offset(rippleOrigin!.dx.clamp(0, size.width), rippleOrigin!.dy.clamp(0, size.height));
      final r = 12 + (size.longestSide * .9 - 12) * ripple;
      final c1 = (dark ? Colors.white : primary).withValues(alpha: (dark ? .48 : .28) * .85 * rippleAlpha);
      final c2 = (dark ? _darkOuter : primary).withValues(alpha: (dark ? .22 : .11) * .45 * rippleAlpha);
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [c1, c2, Colors.transparent],
          ).createShader(Rect.fromCircle(center: origin, radius: math.max(r, 1))),
      );
    }
  }

  @override
  bool shouldRepaint(_BloomPainter old) => true;
}

/// A frosted glass surface: the backdrop is blurred, then tinted with [glassDecoration].
///
/// Uses [DecoratedBox] rather than `Container.decoration`, because Container insets its child by
/// the border width, which would squeeze fixed-width content such as the dock's items.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.shape,
    required this.tint,
    required this.child,
    this.borderAlpha = .82,
    this.shadowElevation = 14,
    this.glow = false,
    this.blur = 18,
  });

  final ShapeBorder shape;
  final Color tint;
  final Widget child;
  final double borderAlpha;
  final double shadowElevation;
  final bool glow;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final deco = glassDecoration(
      context,
      shape: shape,
      tint: tint,
      borderAlpha: borderAlpha,
      shadowElevation: shadowElevation,
      glow: glow,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: deco.shadows),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: ShapeDecoration(shape: deco.shape, gradient: deco.gradient),
            child: child,
          ),
        ),
      ),
    );
  }
}
