import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:msgs/services/wallpaper/wallpaper_colors.dart';

import 'expressive_dock.dart' show kDockReserve;
import 'glass.dart';
import 'motion.dart';
import 'shapes.dart';
import 'theme/expressive_theme.dart';

/*
 * The shared Material 3 Expressive building blocks. Every screen is assembled from these, so a
 * change to a radius or a colour role reaches the whole app at once.
 *
 * Ported from Expressive Clock (github.com/samuelbeckman/expressive-clock), itself a fork of
 * Material Clock by Rayane Bouafia. MIT.
 */

// ─────────────────────────────────────────────────────────────────────────────────────────────
// Headers
// ─────────────────────────────────────────────────────────────────────────────────────────────

/// Big screen title (displayMediumEmphasized) + a primary titleLargeEmphasized subtitle. The title
/// springs vertically when it changes.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing = const []});

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SpringSwitcher(
                  child: FittedBox(
                    key: ValueKey(title),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: context.type.displayMediumEmphasized.copyWith(color: context.colors.onSurface),
                    ),
                  ),
                ),
                if (subtitle != null)
                  AnimatedSwitcher(
                    duration: Motion.colour,
                    child: Text(
                      subtitle!,
                      key: ValueKey(subtitle),
                      style: context.type.titleLargeEmphasized.copyWith(color: context.colors.primary),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < trailing.length; i++) ...[if (i > 0) const SizedBox(width: 8), trailing[i]],
        ],
      ),
    );
  }
}

class _SpringSwitcher extends StatelessWidget {
  const _SpringSwitcher({required this.child});
  final Widget child;

  static final _curve = SpringCurve(Motion.titleChange);

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _curve.settleDuration,
    switchInCurve: _curve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
    transitionBuilder: (child, anim) {
      final incoming = child.key == this.child.key;
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: const Interval(0, .5)),
        child: SlideTransition(
          position: Tween(begin: Offset(0, incoming ? .45 : -.45), end: Offset.zero).animate(anim),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// A circle with an icon (prev/next, small actions). primaryContainer by default.
class RoundTonalButton extends StatelessWidget {
  const RoundTonalButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 48,
    this.container,
    this.content,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? container;
  final Color? content;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: LuminousElastic.small(
        onTap: onTap,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: Motion.colour,
          width: size,
          height: size,
          decoration: ShapeDecoration(shape: Shapes.circle, color: container ?? context.colors.primaryContainer),
          child: Icon(icon, color: content ?? context.colors.onPrimaryContainer, size: (size * .5).clamp(16, 24)),
        ),
      ),
    );
  }
}

/// Sub-page top bar: 52dp tonal back circle + headlineLargeEmphasized title.
class BackTitleBar extends StatelessWidget {
  const BackTitleBar({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        RoundTonalButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: onBack, size: 52),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.headlineLargeEmphasized.copyWith(color: context.colors.onSurface),
          ),
        ),
      ],
    ),
  );
}

/// Section heading inside a list: headlineSmallEmphasized in primary.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
    child: Text(text, style: context.type.headlineSmallEmphasized.copyWith(color: context.colors.primary)),
  );
}

/// Fades content out under the status bar so scrolled text never collides with the clock.
class StatusBarFade extends StatelessWidget {
  const StatusBarFade({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bg = context.colors.surface;
    return IgnorePointer(
      child: Container(
        height: top + 12,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg, bg.withValues(alpha: .92), bg.withValues(alpha: 0)],
            stops: const [0, .7, 1],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────────────────
// Sheets
// ─────────────────────────────────────────────────────────────────────────────────────────────

/// Opens a bottom sheet with the 32dp top shape, fully expanded.
Future<T?> showExpressiveSheet<T>(BuildContext context, {required WidgetBuilder builder, bool fullHeight = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: Shapes.sheet,
    backgroundColor: context.colors.surfaceContainerLow,
    builder: (ctx) {
      final content = Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(top: false, child: builder(ctx)),
      );
      return fullHeight ? SizedBox(height: MediaQuery.sizeOf(ctx).height * .92, child: content) : content;
    },
  );
}

/// Cancel / Save style pill for sheet headers.
class SheetHeaderButton extends StatelessWidget {
  const SheetHeaderButton({
    super.key,
    required this.text,
    required this.onTap,
    this.primary = false,
    this.icon,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onTap;
  final bool primary;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = !enabled
        ? c.onSurface.withValues(alpha: .10)
        : primary
        ? c.primary
        : c.primaryContainer.withValues(alpha: .70);
    final fg = !enabled
        ? c.onSurface.withValues(alpha: .38)
        : primary
        ? c.onPrimary
        : c.onPrimaryContainer;
    return LuminousElastic(
      shape: Shapes.pill,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Motion.colour,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: ShapeDecoration(shape: Shapes.pill, color: bg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
            Text(text, style: context.type.labelLargeEmphasized.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Header row for create/edit sheets: [leading] · title · [trailing].
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.leading, this.trailing});

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Row(
      children: [
        leading ?? const SizedBox(width: 46),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.titleLargeEmphasized.copyWith(color: context.colors.onSurface),
          ),
        ),
        trailing ?? const SizedBox(width: 46),
      ],
    ),
  );
}

/// A rounded group inside a sheet: surfaceContainerHigh, 26dp.
class SheetGroup extends StatelessWidget {
  const SheetGroup({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: ShapeDecoration(shape: Shapes.sheetGroup, color: color ?? context.colors.surfaceContainerHigh),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// The badge + headline at the top of a details sheet.
class DetailsHeader extends StatelessWidget {
  const DetailsHeader({super.key, required this.badge, required this.title, this.subtitle});

  final Widget badge;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
    child: Row(
      children: [
        badge,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.type.headlineMediumEmphasized.copyWith(color: context.colors.onSurface),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 44dp primaryContainer pill showing a value.
class ValuePill extends StatelessWidget {
  const ValuePill({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LuminousElastic.small(
    shape: Shapes.pill,
    onTap: onTap,
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: ShapeDecoration(shape: Shapes.pill, color: context.colors.primaryContainer),
      child: Center(
        widthFactor: 1,
        child: Text(text, style: context.type.labelLargeEmphasized.copyWith(color: context.colors.onPrimaryContainer)),
      ),
    ),
  );
}

/// Full-width 60dp primary action.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.text,
    required this.onTap,
    this.container,
    this.content,
    this.icon,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onTap;
  final Color? container;
  final Color? content;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bg = container ?? context.colors.primary;
    final fg = content ?? context.colors.onPrimary;
    return LuminousElastic(
      shape: Shapes.cta,
      maxStretch: .04,
      enabled: onTap != null && !loading,
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: Motion.colour,
        height: 60,
        decoration: ShapeDecoration(shape: Shapes.cta, color: bg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              ExpressiveLoadingIndicator(size: 28, color: fg)
            else ...[
              if (icon != null) ...[Icon(icon, color: fg), const SizedBox(width: 8)],
              Text(text, style: context.type.titleMediumEmphasized.copyWith(color: fg)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────────────────
// Settings rows
// ─────────────────────────────────────────────────────────────────────────────────────────────

/// A titled group card: 28dp corners, UPPERCASE labelLargeEmphasized onSurfaceVariant heading.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.only(top: title != null ? 18 : 8, bottom: 8),
    decoration: ShapeDecoration(shape: Shapes.group, color: context.groupContainer),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              title!.toUpperCase(),
              style: context.type.labelLargeEmphasized.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
        ],
        ...children,
      ],
    ),
  );
}

/// 46dp, 15dp-corner icon chip. primaryContainer in light, primary in dark.
class SettingIcon extends StatelessWidget {
  const SettingIcon(this.icon, {super.key, this.tint});

  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = context.isAppDark;
    final c = context.colors;
    final bg = tint?.withValues(alpha: dark ? .9 : .22) ?? (dark ? c.primary : c.primaryContainer);
    final fg = tint != null
        ? (dark ? (ThemeData.estimateBrightnessForColor(tint!) == Brightness.dark ? c.surface : c.onSurface) : tint!)
        : (dark ? c.onPrimary : c.onPrimaryContainer);
    return Container(
      width: 46,
      height: 46,
      decoration: ShapeDecoration(shape: Shapes.chip, color: bg),
      child: Icon(icon, size: 23, color: fg),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.onTap, required this.children});
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LuminousElastic(
    shape: Shapes.row,
    maxStretch: .03,
    maxTranslate: 1.2,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: children),
    ),
  );
}

class _RowText extends StatelessWidget {
  const _RowText(this.title, this.subtitle, {this.titleColor});
  final String title;
  final String? subtitle;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.titleMedium?.copyWith(color: titleColor ?? context.colors.onSurface)),
        if (subtitle != null)
          Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
      ],
    ),
  );
}

/// Row that navigates/opens a picker. Chevron, or a tonal value pill if [trailing] is set.
class SettingsNavigateRow extends StatelessWidget {
  const SettingsNavigateRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconTint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? iconTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _RowShell(
    onTap: onTap,
    children: [
      SettingIcon(icon, tint: iconTint),
      const SizedBox(width: 14),
      _RowText(title, subtitle),
      if (trailing != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: ShapeDecoration(shape: Shapes.pill, color: context.colors.primaryContainer),
          child: Text(trailing!, style: context.text.labelLarge?.copyWith(color: context.colors.onPrimaryContainer)),
        )
      else
        Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
    ],
  );
}

/// Whole-row toggle with a trailing Switch.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _RowShell(
    onTap: () => onChanged(!value),
    children: [
      SettingIcon(icon),
      const SizedBox(width: 14),
      _RowText(title, subtitle),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

/// An action row inside a [SheetGroup]. [destructive] uses the error roles.
class SheetActionRow extends StatelessWidget {
  const SheetActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _RowShell(
      onTap: onTap,
      children: [
        if (destructive)
          Container(
            width: 46,
            height: 46,
            decoration: ShapeDecoration(shape: Shapes.chip, color: c.errorContainer),
            child: Icon(icon, size: 23, color: c.onErrorContainer),
          )
        else
          SettingIcon(icon),
        const SizedBox(width: 14),
        _RowText(title, subtitle, titleColor: destructive ? c.error : null),
      ],
    );
  }
}

/// Hairline between rows, inset to the text column (76dp).
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 76, right: 20),
    height: 1,
    color: context.colors.outlineVariant.withValues(alpha: .45),
  );
}

/// Radio-list dialog for short mutually exclusive choices.
Future<T?> showChoicePicker<T>(
  BuildContext context, {
  required String title,
  required T value,
  required List<T> options,
  required String Function(T) label,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: RadioGroup<T>(
        groupValue: value,
        onChanged: (v) => Navigator.pop(ctx, v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              LuminousElastic(
                shape: Shapes.r(16),
                maxStretch: .03,
                onTap: () => Navigator.pop(ctx, o),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Radio<T>(value: o),
                      const SizedBox(width: 8),
                      Text(label(o), style: ctx.text.bodyLarge),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [SheetHeaderButton(text: 'Cancel', onTap: () => Navigator.pop(ctx))],
    ),
  );
}

/// Confirmation dialog. Returns true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.delete_outline_rounded,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return AlertDialog(
        // The dialog's icon slot stretches its child to the full width; centre the badge so it
        // keeps its 56dp cookie shape.
        icon: Center(
          child: ShapeBox(
            size: 56,
            shape: CookieBorder.cookie9,
            color: destructive ? c.errorContainer : c.primaryContainer,
            child: Icon(icon, color: destructive ? c.onErrorContainer : c.onPrimaryContainer),
          ),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        // One row of two equal pills. Passing them as separate actions let the wide confirm pill
        // overflow the bar, which then stacked the buttons vertically.
        actions: [
          Row(
            children: [
              Expanded(
                child: _DialogPill(
                  label: 'Cancel',
                  color: c.surfaceContainerHighest,
                  textColor: c.onSurface,
                  onTap: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DialogPill(
                  label: confirmLabel,
                  color: destructive ? c.error : c.primary,
                  textColor: destructive ? c.onError : c.onPrimary,
                  onTap: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _DialogPill extends StatelessWidget {
  const _DialogPill({required this.label, required this.color, required this.textColor, required this.onTap});

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LuminousElastic(
    shape: Shapes.pill,
    maxStretch: .05,
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: ShapeDecoration(shape: Shapes.pill, color: color),
      child: Center(
        child: Text(label, style: context.type.labelLargeEmphasized.copyWith(color: textColor)),
      ),
    ),
  );
}

/// "Colour theme" row: Wallpaper + palette swatches (56dp circles, check when selected).
class PalettePickerRow extends StatelessWidget {
  const PalettePickerRow({
    super.key,
    required this.dynamicColor,
    required this.selected,
    required this.onDynamic,
    required this.onSelect,
  });

  final bool dynamicColor;
  final Palette selected;
  final VoidCallback onDynamic;
  final ValueChanged<Palette> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = context.isAppDark;
    final wallpaper = context.watch<WallpaperSchemes>().of(dark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SettingIcon(Icons.palette_outlined),
                const SizedBox(width: 14),
                const _RowText('Colour theme', 'Personalise the look of the app'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 76),
            child: Row(
              children: [
                if (wallpaper != null) _Swatch('Wallpaper', wallpaper.primary, dynamicColor, onDynamic),
                for (final p in Palette.values)
                  _Swatch(
                    p.displayName,
                    p.scheme(dark).primary,
                    !(dynamicColor && wallpaper != null) && p == selected,
                    () => onSelect(p),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, this.selected, this.onTap);
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            LuminousElastic.small(
              onTap: onTap,
              semanticLabel: '$name theme${selected ? ', selected' : ''}',
              child: AnimatedContainer(
                duration: Motion.colour,
                width: 56,
                height: 56,
                decoration: ShapeDecoration(color: color, shape: selected ? CookieBorder.cookie9 : Shapes.circle),
                child: selected ? SpringIn(child: Icon(Icons.check_rounded, color: onColor, size: 24)) : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: context.colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────────────────
// Content tiles
// ─────────────────────────────────────────────────────────────────────────────────────────────

/// The default list item: 24dp tonal tile, 6dp accent pill, titleMediumEmphasized title.
class AccentTile extends StatelessWidget {
  const AccentTile({super.key, required this.title, this.supporting, required this.accent, this.onTap, this.trailing});

  final String title;
  final String? supporting;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LuminousElastic.tile(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      decoration: ShapeDecoration(
        color: context.groupContainer.withValues(alpha: .94),
        shape: Shapes.tile.copyWith(
          side: BorderSide(color: context.colors.outlineVariant.withValues(alpha: .35), width: 1.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 44,
            decoration: ShapeDecoration(shape: const StadiumBorder(), color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.titleMediumEmphasized.copyWith(color: context.colors.onSurface),
                ),
                if (supporting != null)
                  Text(supporting!, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// Outlined empty state with an expressive badge and an optional tonal action pill.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: ShapeDecoration(
      shape: Shapes.tile.copyWith(
        side: BorderSide(color: context.colors.outlineVariant.withValues(alpha: .6), width: 1.25),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShapeBox(
          size: 72,
          shape: CookieBorder.cookie12,
          color: context.colors.primaryContainer,
          child: Icon(icon, size: 32, color: context.colors.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 14),
          SheetHeaderButton(text: actionLabel!, onTap: onAction!),
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────────────────────
// Feedback
// ─────────────────────────────────────────────────────────────────────────────────────────────

/// Expressive loading indicator: a rotating cookie whose scallops breathe in and out. Never a plain
/// circular spinner.
class ExpressiveLoadingIndicator extends StatefulWidget {
  const ExpressiveLoadingIndicator({super.key, this.size = 48, this.color, this.contained = false});

  final double size;
  final Color? color;

  /// Draws it on a primaryContainer circle.
  final bool contained;

  @override
  State<ExpressiveLoadingIndicator> createState() => _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? (widget.contained ? context.colors.onPrimaryContainer : context.colors.primary);
    final inner = widget.contained ? widget.size * .62 : widget.size;
    final indicator = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Scallops flatten to a circle at t = 0 and .5, which is where the side count swaps, so
        // the morph has no visible pop.
        final wave = (1 - math.cos(t * 4 * math.pi)) / 2;
        final sides = t < .5 ? 7 : 9;
        final depth = .04 + .14 * wave;
        return Transform.rotate(
          angle: Curves.easeInOutCubic.transform(t) * 2 * math.pi,
          child: Transform.scale(
            scale: .86 + .14 * wave,
            child: ShapeBox(
              size: inner,
              shape: CookieBorder(sides: sides, depth: depth, sharpness: 1 + wave * .6),
              color: color,
            ),
          ),
        );
      },
    );
    return Semantics(
      label: 'Loading',
      child: widget.contained
          ? ShapeBox(size: widget.size, shape: Shapes.circle, color: context.colors.primaryContainer, child: indicator)
          : SizedBox.square(
              dimension: widget.size,
              child: Center(child: indicator),
            ),
    );
  }
}

/// Floating snackbar; [aboveDock] lifts it clear of the floating dock.
void showExpressiveSnack(
  BuildContext context,
  String message, {
  bool aboveDock = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final bottom = aboveDock ? kDockReserve + MediaQuery.paddingOf(context).bottom - 8 : 16.0;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        duration: Duration(seconds: onAction == null ? 2 : 4),
        action: onAction == null ? null : SnackBarAction(label: actionLabel ?? 'Undo', onPressed: onAction),
      ),
    );
}
