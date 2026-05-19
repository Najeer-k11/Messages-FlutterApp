import 'package:flutter/material.dart';

/// Centralized motion engine for Msgs
/// Defines durations, curves, and standard spring physics mimicking organic/Apple-like feel.
class MotionEngine {
  // Durations
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 400);
  static const Duration durationSlow = Duration(milliseconds: 600);
  static const Duration durationVerySlow = Duration(milliseconds: 1000);

  // Curves - emphasizing "Slow in -> Fast out" (EaseOut) or spring-like behavior
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveBouncy = Curves.elasticOut;
  static const Curve curveSmooth = Curves.fastLinearToSlowEaseIn;

  // Custom Scrolling Physics
  /// A bouncy scroll physics that stretches more at the edges
  static const ScrollPhysics smoothScrollPhysics = BouncingScrollPhysics(
    decelerationRate: ScrollDecelerationRate.normal,
    parent: AlwaysScrollableScrollPhysics(),
  );
}

class MsgsScrollBehavior extends ScrollBehavior {
  const MsgsScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return MotionEngine.smoothScrollPhysics;
  }
}
