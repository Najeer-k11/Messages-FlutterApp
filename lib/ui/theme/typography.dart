import 'package:material_ui/material_ui.dart';

/// The Material 3 Expressive type scale on a single bundled variable font, Google Sans Flex
/// (SIL OFL 1.1).
///
/// The published M3 scale splits roles between Google Sans and Google Sans Text; the latter is not
/// licensed for third-party use. The split is an optical-size distinction, and the spec's own
/// tokens set `opsz` equal to the font size, so every style here pins `opsz` to its point size.
/// Tracking follows the published Google Sans scale, not the Roboto-tuned defaults.
///
/// Flutter's [TextTheme] has no emphasized slots, so those 15 styles live on the
/// [ExpressiveType] theme extension. Read them through `context.type`.
const String kFontFamily = 'GoogleSansFlex';

const int _regular = 400;
const int _medium = 500;
const int _bold = 700;

TextStyle _style(double size, double lineHeight, int weight, [double tracking = 0]) {
  final opsz = size.clamp(6.0, 144.0);
  return TextStyle(
    fontFamily: kFontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    letterSpacing: tracking,
    fontVariations: [FontVariation('wght', weight.toDouble()), FontVariation('opsz', opsz)],
  );
}

TextTheme expressiveTextTheme() => TextTheme(
  displayLarge: _style(57, 64, _regular),
  displayMedium: _style(45, 52, _regular),
  displaySmall: _style(36, 44, _regular),
  headlineLarge: _style(32, 40, _regular),
  headlineMedium: _style(28, 36, _regular),
  headlineSmall: _style(24, 32, _regular),
  titleLarge: _style(22, 28, _regular),
  titleMedium: _style(16, 24, _medium),
  titleSmall: _style(14, 20, _medium),
  bodyLarge: _style(16, 24, _regular),
  bodyMedium: _style(14, 20, _regular),
  bodySmall: _style(12, 16, _regular, 0.1),
  labelLarge: _style(14, 20, _medium),
  labelMedium: _style(12, 16, _medium, 0.1),
  labelSmall: _style(11, 16, _medium, 0.1),
);

/// The 15 emphasized styles. Same size and line height as the base slot, heavier weight. Use them
/// to mark the one thing on a screen that matters most.
@immutable
class ExpressiveType extends ThemeExtension<ExpressiveType> {
  const ExpressiveType({
    required this.displayLargeEmphasized,
    required this.displayMediumEmphasized,
    required this.displaySmallEmphasized,
    required this.headlineLargeEmphasized,
    required this.headlineMediumEmphasized,
    required this.headlineSmallEmphasized,
    required this.titleLargeEmphasized,
    required this.titleMediumEmphasized,
    required this.titleSmallEmphasized,
    required this.bodyLargeEmphasized,
    required this.bodyMediumEmphasized,
    required this.bodySmallEmphasized,
    required this.labelLargeEmphasized,
    required this.labelMediumEmphasized,
    required this.labelSmallEmphasized,
  });

  factory ExpressiveType.standard() => ExpressiveType(
    displayLargeEmphasized: _style(57, 64, _medium),
    displayMediumEmphasized: _style(45, 52, _medium),
    displaySmallEmphasized: _style(36, 44, _medium),
    headlineLargeEmphasized: _style(32, 40, _medium),
    headlineMediumEmphasized: _style(28, 36, _medium),
    headlineSmallEmphasized: _style(24, 32, _medium),
    titleLargeEmphasized: _style(22, 28, _medium),
    titleMediumEmphasized: _style(16, 24, _bold),
    titleSmallEmphasized: _style(14, 20, _bold),
    bodyLargeEmphasized: _style(16, 24, _medium),
    bodyMediumEmphasized: _style(14, 20, _medium),
    bodySmallEmphasized: _style(12, 16, _medium, 0.1),
    labelLargeEmphasized: _style(14, 20, _bold),
    labelMediumEmphasized: _style(12, 16, _bold, 0.1),
    labelSmallEmphasized: _style(11, 16, _bold, 0.1),
  );

  final TextStyle displayLargeEmphasized;
  final TextStyle displayMediumEmphasized;
  final TextStyle displaySmallEmphasized;
  final TextStyle headlineLargeEmphasized;
  final TextStyle headlineMediumEmphasized;
  final TextStyle headlineSmallEmphasized;
  final TextStyle titleLargeEmphasized;
  final TextStyle titleMediumEmphasized;
  final TextStyle titleSmallEmphasized;
  final TextStyle bodyLargeEmphasized;
  final TextStyle bodyMediumEmphasized;
  final TextStyle bodySmallEmphasized;
  final TextStyle labelLargeEmphasized;
  final TextStyle labelMediumEmphasized;
  final TextStyle labelSmallEmphasized;

  @override
  ExpressiveType copyWith() => this;

  @override
  ExpressiveType lerp(ExpressiveType? other, double t) => this;
}
