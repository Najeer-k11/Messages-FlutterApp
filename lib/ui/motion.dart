import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Motion tokens. Spatial movement uses under-damped springs (things overshoot); colour and alpha
/// use tweens, never springs.
abstract final class Motion {
  static SpringDescription spring(double dampingRatio, double stiffness) =>
      SpringDescription.withDampingRatio(mass: 1, stiffness: stiffness, ratio: dampingRatio);

  static final dockIndicator = spring(0.84, 600);
  static final addButton = spring(0.9, 620);
  static final selection = spring(0.45, 380);
  static final selectionRotation = spring(0.6, 220);
  static final pillAppear = spring(0.5, 500);
  static final titleChange = spring(0.7, 400);
  static final onboarding = spring(0.82, 380);
  static final pressRelease = spring(0.52, 350);
  static final chipGrow = spring(0.55, 500);

  static const settingsOpen = Duration(milliseconds: 420);
  static const settingsClose = Duration(milliseconds: 320);
  static const colour = Duration(milliseconds: 220);
}

/// A curve that follows a spring from 0 to 1, for transitions driven by a normal
/// [AnimationController] (route transitions, AnimatedSwitcher). Overshoots like the spring does.
class SpringCurve extends Curve {
  SpringCurve(this.spring)
    : _sim = SpringSimulation(spring, 0, 1, 0, tolerance: const Tolerance(distance: 0.002, velocity: 0.02)) {
    var t = 0.0;
    while (t < 3 && !_sim.isDone(t)) {
      t += 1 / 120;
    }
    _settleSeconds = t;
  }

  final SpringDescription spring;
  final SpringSimulation _sim;
  late final double _settleSeconds;

  /// Time for the spring to settle, used to size the transition's duration.
  Duration get settleDuration => Duration(milliseconds: (_settleSeconds * 1000).round());

  @override
  double transformInternal(double t) => t >= 1 ? 1 : _sim.x(_settleSeconds * t);
}

/// Animates a double toward [value] with a spring, preserving velocity when the target changes
/// mid-flight. If [from] is set, the first build springs from it.
class SpringBuilder extends StatefulWidget {
  const SpringBuilder({
    super.key,
    required this.value,
    required this.spring,
    required this.builder,
    this.from,
    this.child,
  });

  final double value;
  final double? from;
  final SpringDescription spring;
  final Widget? child;
  final Widget Function(BuildContext context, double value, Widget? child) builder;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: widget.from ?? widget.value);

  @override
  void initState() {
    super.initState();
    if (widget.from != null && widget.from != widget.value) _go();
  }

  @override
  void didUpdateWidget(SpringBuilder old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _go();
  }

  void _go() => _c.animateWith(SpringSimulation(widget.spring, _c.value, widget.value, _c.velocity));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => widget.builder(context, _c.value, child),
  );
}

/// Springs a child in: scale 0→1 plus rotation -60°→0, the selection "moment".
class SpringIn extends StatelessWidget {
  const SpringIn({super.key, required this.child, this.rotate = true});

  final Widget child;
  final bool rotate;

  @override
  Widget build(BuildContext context) => SpringBuilder(
    from: 0,
    value: 1,
    spring: Motion.selection,
    child: child,
    builder: (context, s, child) => SpringBuilder(
      from: rotate ? -60 : 0,
      value: 0,
      spring: Motion.selectionRotation,
      child: child,
      builder: (context, deg, child) => Transform.rotate(
        angle: deg * 3.1415926535 / 180,
        child: Transform.scale(scale: s.clamp(0.0, 2.0), child: child),
      ),
    ),
  );
}
