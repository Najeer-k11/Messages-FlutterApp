import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'glass.dart';
import 'motion.dart';
import 'theme/expressive_theme.dart';

/// How a dock icon reacts when tapped. Give each destination a different one.
enum TapMotion { flip, wiggle, halfTurn, fullTurn }

class DockDestination {
  const DockDestination(this.key, this.label, this.icon, this.selectedIcon, this.motion, {this.badge = 0});

  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final TapMotion motion;
  final int badge;
}

const double kDockHeight = 72;

/// Bottom padding every scrolling screen reserves so its last item clears the floating dock.
const double kDockReserve = kDockHeight + 20 + 12;

/// The floating glass navigation dock: a frosted pill with a sliding circular indicator
/// (white in light, #24303B in dark) plus a detached round "+" action.
///
/// Place it bottom-centre over full-bleed content, padded by the navigation-bar inset + 20dp. No
/// NavigationBar, no Scaffold bottom bar.
class ExpressiveDock extends StatelessWidget {
  const ExpressiveDock({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    this.showAdd = true,
    this.addLabel = 'Add',
    this.addIcon = Icons.add_rounded,
    this.onAdd,
  });

  final List<DockDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool showAdd;
  final String addLabel;
  final IconData addIcon;
  final VoidCallback? onAdd;

  static const _itemWidth = 68.0;
  static const _indicator = 50.0;

  @override
  Widget build(BuildContext context) {
    final dark = context.isAppDark;
    final c = context.colors;
    final dockTint = dark ? c.surfaceContainer.withValues(alpha: .88) : c.surfaceContainerLow.withValues(alpha: .84);
    const dockShape = StadiumBorder();
    final width = _itemWidth * destinations.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LuminousElastic(
          shape: dockShape,
          maxStretch: .06,
          maxTranslate: 1.8,
          child: Glass(
            shape: dockShape,
            tint: dockTint,
            borderAlpha: .88,
            shadowElevation: 18,
            glow: true,
            child: SizedBox(
              width: width,
              height: kDockHeight,
              child: Stack(
                children: [
                  SpringBuilder(
                    value: selected.toDouble(),
                    spring: Motion.dockIndicator,
                    builder: (context, i, _) => Positioned(
                      left: _itemWidth * i + (_itemWidth - _indicator) / 2,
                      top: (kDockHeight - _indicator) / 2,
                      child: Container(
                        width: _indicator,
                        height: _indicator,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // The one documented hard-coded colour in the system.
                          color: dark ? const Color(0xFF24303B) : Colors.white.withValues(alpha: .99),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        _DockItem(
                          destination: destinations[i],
                          selected: i == selected,
                          iconColor: dark ? Colors.white.withValues(alpha: .94) : c.primary,
                          onTap: () => onSelect(i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Detached add: alpha tween + spring scale from .78; collapses its gap when hidden.
        if (onAdd != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: showAdd ? kDockHeight + 10 : 0,
            height: kDockHeight,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: kDockHeight + 10,
              maxWidth: kDockHeight + 10,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _AddButton(visible: showAdd, label: addLabel, icon: addIcon, onTap: onAdd),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.visible, required this.label, required this.icon, required this.onTap});

  final bool visible;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isAppDark;
    final c = context.colors;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: SpringBuilder(
          from: .78,
          value: visible ? 1 : .78,
          spring: Motion.addButton,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: LuminousElastic(
            maxStretch: .08,
            maxTranslate: 2,
            onTap: onTap,
            semanticLabel: label,
            child: Glass(
              shape: const CircleBorder(),
              tint: c.primaryContainer.withValues(alpha: dark ? .72 : .58),
              borderAlpha: .92,
              shadowElevation: 18,
              glow: true,
              child: SizedBox.square(
                dimension: kDockHeight,
                child: Icon(icon, size: 31, color: c.onPrimaryContainer),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({required this.destination, required this.selected, required this.iconColor, required this.onTap});

  final DockDestination destination;
  final bool selected;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> with SingleTickerProviderStateMixin {
  late final _rot = AnimationController.unbounded(vsync: this);

  @override
  void dispose() {
    _rot.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    _rot.value = 0;
    switch (widget.destination.motion) {
      case TapMotion.flip:
      case TapMotion.fullTurn:
        await _rot.animateTo(360, duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);
      case TapMotion.halfTurn:
        await _rot.animateTo(180, duration: const Duration(milliseconds: 320), curve: Curves.easeInOutCubic);
      case TapMotion.wiggle:
        await _rot.animateTo(-6, duration: const Duration(milliseconds: 65));
        await _rot.animateTo(6, duration: const Duration(milliseconds: 85));
        await _rot.animateTo(-3, duration: const Duration(milliseconds: 65));
        await _rot.animateTo(0, duration: const Duration(milliseconds: 65));
    }
    if (mounted) _rot.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.destination;
    final c = context.colors;
    final flip = d.motion == TapMotion.flip;
    return Semantics(
      selected: widget.selected,
      button: true,
      label: d.badge > 0 ? '${d.label}, ${d.badge} unread' : d.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _play();
          widget.onTap();
        },
        child: SizedBox(
          width: ExpressiveDock._itemWidth,
          height: kDockHeight,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _rot,
                  builder: (context, child) {
                    final a = _rot.value * math.pi / 180;
                    final m = Matrix4.identity()..setEntry(3, 2, 0.0012);
                    flip ? m.rotateY(a) : m.rotateZ(a);
                    return Transform(transform: m, alignment: Alignment.center, child: child);
                  },
                  child: AnimatedScale(
                    scale: widget.selected ? 1 : .94,
                    duration: const Duration(milliseconds: 180),
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: widget.selected ? c.onSurface : widget.iconColor),
                      duration: Motion.colour,
                      builder: (context, color, _) =>
                          Icon(widget.selected ? d.selectedIcon : d.icon, size: 27, color: color),
                    ),
                  ),
                ),
                if (d.badge > 0)
                  Positioned(
                    right: -7,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(shape: const StadiumBorder(), color: c.primary),
                      child: Text(
                        d.badge > 99 ? '99+' : '${d.badge}',
                        style: context.type.labelSmallEmphasized.copyWith(color: c.onPrimary, height: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
