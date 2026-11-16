import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'palettes.dart';
import 'typography.dart';

export 'palettes.dart';
export 'typography.dart';

enum DarkMode {
  system('System'),
  light('Light'),
  dark('Dark');

  const DarkMode(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    DarkMode.system => ThemeMode.system,
    DarkMode.light => ThemeMode.light,
    DarkMode.dark => ThemeMode.dark,
  };
}

/// Theme preferences, persisted in SharedPreferences by [ThemeSettingsNotifier].
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.dynamicColor = true,
    this.palette = Palette.concept,
    this.darkMode = DarkMode.system,
    this.amoledBlack = false,
  });

  /// Wallpaper colour (Android 12+). Falls back to [palette] when off or unavailable.
  final bool dynamicColor;
  final Palette palette;
  final DarkMode darkMode;

  /// True-black surfaces in dark mode, for OLED panels.
  final bool amoledBlack;

  ThemeSettings copyWith({bool? dynamicColor, Palette? palette, DarkMode? darkMode, bool? amoledBlack}) =>
      ThemeSettings(
        dynamicColor: dynamicColor ?? this.dynamicColor,
        palette: palette ?? this.palette,
        darkMode: darkMode ?? this.darkMode,
        amoledBlack: amoledBlack ?? this.amoledBlack,
      );
}

class ThemeSettingsNotifier extends ValueNotifier<ThemeSettings> {
  ThemeSettingsNotifier._(super.value, this._prefs);

  final SharedPreferences _prefs;

  // `theme_mode` predates this class; the key and its values are kept so upgrades keep the choice.
  static const _kMode = 'theme_mode';
  static const _kDynamic = 'theme_dynamic_color';
  static const _kPalette = 'theme_palette';
  static const _kAmoled = 'theme_amoled_black';

  static Future<ThemeSettingsNotifier> create() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = switch (prefs.getString(_kMode)) {
      'light' => DarkMode.light,
      'dark' => DarkMode.dark,
      _ => DarkMode.system,
    };
    final palette = Palette.values.firstWhere(
      (p) => p.name == prefs.getString(_kPalette),
      orElse: () => Palette.concept,
    );
    return ThemeSettingsNotifier._(
      ThemeSettings(
        darkMode: mode,
        palette: palette,
        dynamicColor: prefs.getBool(_kDynamic) ?? true,
        amoledBlack: prefs.getBool(_kAmoled) ?? false,
      ),
      prefs,
    );
  }

  Future<void> update(ThemeSettings next) async {
    value = next;
    await Future.wait([
      _prefs.setString(_kMode, next.darkMode.name),
      _prefs.setBool(_kDynamic, next.dynamicColor),
      _prefs.setString(_kPalette, next.palette.name),
      _prefs.setBool(_kAmoled, next.amoledBlack),
    ]);
  }
}

/// Resolves the scheme for one brightness: the wallpaper scheme when enabled and available
/// (read natively, complete with every surface-container role), otherwise the chosen preset.
ColorScheme resolveScheme({required ThemeSettings settings, required bool dark, ColorScheme? wallpaper}) {
  final base = (settings.dynamicColor && wallpaper != null) ? wallpaper : settings.palette.scheme(dark);
  return (dark && settings.amoledBlack) ? base.toAmoledBlack() : base;
}

extension AmoledScheme on ColorScheme {
  /// True-black variant of a dark scheme. Accent roles and the upper containers are untouched, so
  /// tiles on `surfaceContainer` gain separation rather than flattening.
  ColorScheme toAmoledBlack() => copyWith(
    surface: Colors.black,
    surfaceDim: Colors.black,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF0A0A0A),
    surfaceContainer: const Color(0xFF141018),
    scrim: Colors.black,
  );
}

ThemeData buildExpressiveTheme(ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  final text = expressiveTextTheme().apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  final type = ExpressiveType.standard();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    extensions: [type],
    // Every tappable surface uses LuminousElastic instead of an ink ripple.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: overlayStyleFor(dark),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: type.headlineSmallEmphasized.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: .28),
      selectionHandleColor: scheme.primary,
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? const Icon(Icons.check_rounded) : null,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: type.labelLargeEmphasized)),
  );
}

SystemUiOverlayStyle overlayStyleFor(bool dark) => SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
  statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  statusBarBrightness: dark ? Brightness.dark : Brightness.light,
  systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
);

extension ExpressiveContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  ExpressiveType get type => Theme.of(this).extension<ExpressiveType>()!;

  /// Effective dark-ness, respecting the in-app override (unlike the platform brightness).
  bool get isAppDark => Theme.of(this).brightness == Brightness.dark;

  /// Card/group background: surfaceContainer in dark, surfaceContainerLow in light.
  Color get groupContainer => isAppDark ? colors.surfaceContainer : colors.surfaceContainerLow;
}
