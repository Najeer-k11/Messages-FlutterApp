import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Polar "cookie" outlines standing in for Compose's `MaterialShapes`, which Flutter lacks.
///
/// The radius at angle a is `R * (1 - depth * (1 - s(a)))`, with `s(a) = ((cos(n*a) + 1) / 2)^p`.
/// `p = 1` gives the soft scallops of the cookies; `p > 1` narrows the peaks into sunbursts. The
/// outline always touches the bounding box, so it can replace a circle of the same size.
class CookieBorder extends OutlinedBorder {
  const CookieBorder({required this.sides, this.depth = 0.08, this.sharpness = 1, this.rotation = 0, super.side});

  /// Selected/today, badges.
  static const cookie9 = CookieBorder(sides: 9, depth: 0.075);

  /// Hero backgrounds.
  static const cookie12 = CookieBorder(sides: 12, depth: 0.06);

  /// Detail colour badges.
  static const cookie7 = CookieBorder(sides: 7, depth: 0.09);

  /// Small markers.
  static const cookie4 = CookieBorder(sides: 4, depth: 0.13, rotation: math.pi / 4);

  /// "Today" in lists, hero centre.
  static const sunny = CookieBorder(sides: 8, depth: 0.12, sharpness: 1.8);

  /// Celebration hero.
  static const softBurst = CookieBorder(sides: 10, depth: 0.16, sharpness: 1.4);

  final int sides;
  final double depth;
  final double sharpness;
  final double rotation;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final c = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    const steps = 240;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final a = 2 * math.pi * i / steps;
      final s = math.pow((math.cos(sides * a) + 1) / 2, sharpness).toDouble();
      final r = 1 - depth * (1 - s);
      final p = Offset(
        c.dx + rx * r * math.cos(a + rotation - math.pi / 2),
        c.dy + ry * r * math.sin(a + rotation - math.pi / 2),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  CookieBorder scale(double t) =>
      CookieBorder(sides: sides, depth: depth, sharpness: sharpness, rotation: rotation, side: side.scale(t));

  @override
  CookieBorder copyWith({BorderSide? side, double? rotation, double? depth}) => CookieBorder(
    sides: sides,
    depth: depth ?? this.depth,
    sharpness: sharpness,
    rotation: rotation ?? this.rotation,
    side: side ?? this.side,
  );

  @override
  bool operator ==(Object other) =>
      other is CookieBorder &&
      other.sides == sides &&
      other.depth == depth &&
      other.sharpness == sharpness &&
      other.rotation == rotation &&
      other.side == side;

  @override
  int get hashCode => Object.hash(sides, depth, sharpness, rotation, side);
}

/// Shape tokens.
abstract final class Shapes {
  static RoundedRectangleBorder r(double radius) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  static final group = r(28);
  static final tile = r(24);
  static final hero = r(32);
  static final sheetGroup = r(26);
  static final row = r(20);
  static final pill = r(18);
  static final chip = r(15);
  static final cta = r(28);
  static const circle = CircleBorder();
  static const sheet = RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32)));
}

/// A filled shape with centred content, the building block of badges and hero art.
class ShapeBox extends StatelessWidget {
  const ShapeBox({super.key, required this.size, required this.shape, required this.color, this.child});

  final double size;
  final ShapeBorder shape;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: ShapeDecoration(shape: shape, color: color),
      child: child == null ? null : Center(child: child),
    ),
  );
}
