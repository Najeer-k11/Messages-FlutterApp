import 'package:flutter/services.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

/// The OS wallpaper (Material You) colour schemes, read natively by `MaterialYouColors.kt`.
///
/// On Android 12+ the five system tonal palettes are rebuilt into a full tonal-spot
/// [DynamicScheme], so every role exists, including the `surfaceContainer*` family. On Android
/// 14+ the exact system role colours are then laid over it, so the app matches the system UI.
/// Below Android 12 [light] and [dark] are null and the app uses its preset palettes.
@immutable
class WallpaperSchemes {
  const WallpaperSchemes({this.light, this.dark});

  static const none = WallpaperSchemes();

  final ColorScheme? light;
  final ColorScheme? dark;

  bool get available => light != null && dark != null;

  ColorScheme? of(bool dark) => dark ? this.dark : light;
}

/// Loads [WallpaperSchemes] and reloads them when the app resumes, since the user may have
/// changed wallpaper or the system colour style while the app was in the background.
class WallpaperColorsNotifier extends ValueNotifier<WallpaperSchemes> with WidgetsBindingObserver {
  WallpaperColorsNotifier._(super.value) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _channel = MethodChannel('com.msgs.ndevmsgs/wallpaper');

  static Future<WallpaperColorsNotifier> create() async => WallpaperColorsNotifier._(await _load());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final next = await _load();
    if (next.light != value.light || next.dark != value.dark) value = next;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static Future<WallpaperSchemes> _load() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('getColors');
      if (raw == null) return WallpaperSchemes.none;
      return parseWallpaperColors(raw);
    } on PlatformException {
      return WallpaperSchemes.none;
    } on MissingPluginException {
      return WallpaperSchemes.none;
    }
  }
}

/// Builds both schemes from the native payload. Exposed for tests.
WallpaperSchemes parseWallpaperColors(Map<String, Object?> raw) {
  final palettes = (raw['palettes'] as Map?)?.cast<String, Object?>();
  if (palettes == null) return WallpaperSchemes.none;

  TonalPalette palette(String name) => TonalPalette.fromList((palettes[name] as List).cast<int>());

  final primary = palette('accent1');
  final secondary = palette('accent2');
  final tertiary = palette('accent3');
  final neutral = palette('neutral1');
  final neutralVariant = palette('neutral2');

  ColorScheme build(bool dark) {
    final scheme = DynamicScheme(
      sourceColorHct: Hct.fromInt(primary.get(40)),
      variant: Variant.tonalSpot,
      isDark: dark,
      primaryPalette: primary,
      secondaryPalette: secondary,
      tertiaryPalette: tertiary,
      neutralPalette: neutral,
      neutralVariantPalette: neutralVariant,
    );
    final base = _fromDynamicScheme(scheme);
    final roles = ((raw['roles'] as Map?)?[dark ? 'dark' : 'light'] as Map?)?.cast<String, int>();
    if (roles == null || !_rolesMatchPalette(roles, primary, dark)) return base;
    return _applySystemRoles(base, roles);
  }

  return WallpaperSchemes(light: build(false), dark: build(true));
}

/// Android 14 exposes ready-made colour roles, but several vendor ROMs (OriginOS / Funtouch among
/// them) only recolour the five tonal palettes on a wallpaper change and leave the role resources
/// at their stock blue defaults. Use the roles only when their primary has the hue of the
/// wallpaper palette's primary (tone 40 in light, 80 in dark); otherwise the palettes, which every
/// Material You ROM updates, are the reliable source.
bool _rolesMatchPalette(Map<String, int> roles, TonalPalette primary, bool dark) {
  final role = roles['primary'];
  if (role == null) return false;
  final a = Hct.fromInt(role);
  final b = Hct.fromInt(primary.get(dark ? 80 : 40));
  if (a.chroma < 8 && b.chroma < 8) return true; // both near-grey: hue is meaningless
  final d = (a.hue - b.hue).abs();
  return (d > 180 ? 360 - d : d) <= 20;
}

ColorScheme _fromDynamicScheme(DynamicScheme s) {
  Color c(DynamicColor role) => Color(role.getArgb(s));
  return ColorScheme(
    brightness: s.isDark ? Brightness.dark : Brightness.light,
    primary: c(MaterialDynamicColors.primary),
    onPrimary: c(MaterialDynamicColors.onPrimary),
    primaryContainer: c(MaterialDynamicColors.primaryContainer),
    onPrimaryContainer: c(MaterialDynamicColors.onPrimaryContainer),
    primaryFixed: c(MaterialDynamicColors.primaryFixed),
    primaryFixedDim: c(MaterialDynamicColors.primaryFixedDim),
    onPrimaryFixed: c(MaterialDynamicColors.onPrimaryFixed),
    onPrimaryFixedVariant: c(MaterialDynamicColors.onPrimaryFixedVariant),
    secondary: c(MaterialDynamicColors.secondary),
    onSecondary: c(MaterialDynamicColors.onSecondary),
    secondaryContainer: c(MaterialDynamicColors.secondaryContainer),
    onSecondaryContainer: c(MaterialDynamicColors.onSecondaryContainer),
    secondaryFixed: c(MaterialDynamicColors.secondaryFixed),
    secondaryFixedDim: c(MaterialDynamicColors.secondaryFixedDim),
    onSecondaryFixed: c(MaterialDynamicColors.onSecondaryFixed),
    onSecondaryFixedVariant: c(MaterialDynamicColors.onSecondaryFixedVariant),
    tertiary: c(MaterialDynamicColors.tertiary),
    onTertiary: c(MaterialDynamicColors.onTertiary),
    tertiaryContainer: c(MaterialDynamicColors.tertiaryContainer),
    onTertiaryContainer: c(MaterialDynamicColors.onTertiaryContainer),
    tertiaryFixed: c(MaterialDynamicColors.tertiaryFixed),
    tertiaryFixedDim: c(MaterialDynamicColors.tertiaryFixedDim),
    onTertiaryFixed: c(MaterialDynamicColors.onTertiaryFixed),
    onTertiaryFixedVariant: c(MaterialDynamicColors.onTertiaryFixedVariant),
    error: c(MaterialDynamicColors.error),
    onError: c(MaterialDynamicColors.onError),
    errorContainer: c(MaterialDynamicColors.errorContainer),
    onErrorContainer: c(MaterialDynamicColors.onErrorContainer),
    surface: c(MaterialDynamicColors.surface),
    onSurface: c(MaterialDynamicColors.onSurface),
    surfaceDim: c(MaterialDynamicColors.surfaceDim),
    surfaceBright: c(MaterialDynamicColors.surfaceBright),
    surfaceContainerLowest: c(MaterialDynamicColors.surfaceContainerLowest),
    surfaceContainerLow: c(MaterialDynamicColors.surfaceContainerLow),
    surfaceContainer: c(MaterialDynamicColors.surfaceContainer),
    surfaceContainerHigh: c(MaterialDynamicColors.surfaceContainerHigh),
    surfaceContainerHighest: c(MaterialDynamicColors.surfaceContainerHighest),
    onSurfaceVariant: c(MaterialDynamicColors.onSurfaceVariant),
    outline: c(MaterialDynamicColors.outline),
    outlineVariant: c(MaterialDynamicColors.outlineVariant),
    shadow: c(MaterialDynamicColors.shadow),
    scrim: c(MaterialDynamicColors.scrim),
    inverseSurface: c(MaterialDynamicColors.inverseSurface),
    onInverseSurface: c(MaterialDynamicColors.inverseOnSurface),
    inversePrimary: c(MaterialDynamicColors.inversePrimary),
    surfaceTint: c(MaterialDynamicColors.surfaceTint),
  );
}

/// Lays the exact Android 14+ system roles over the derived scheme. Missing roles keep the
/// derived value.
ColorScheme _applySystemRoles(ColorScheme base, Map<String, int> roles) {
  Color? r(String name) => roles[name] == null ? null : Color(roles[name]!);
  return base.copyWith(
    primary: r('primary'),
    onPrimary: r('on_primary'),
    primaryContainer: r('primary_container'),
    onPrimaryContainer: r('on_primary_container'),
    inversePrimary: r('inverse_primary'),
    primaryFixed: r('primary_fixed'),
    primaryFixedDim: r('primary_fixed_dim'),
    onPrimaryFixed: r('on_primary_fixed'),
    onPrimaryFixedVariant: r('on_primary_fixed_variant'),
    secondary: r('secondary'),
    onSecondary: r('on_secondary'),
    secondaryContainer: r('secondary_container'),
    onSecondaryContainer: r('on_secondary_container'),
    secondaryFixed: r('secondary_fixed'),
    secondaryFixedDim: r('secondary_fixed_dim'),
    onSecondaryFixed: r('on_secondary_fixed'),
    onSecondaryFixedVariant: r('on_secondary_fixed_variant'),
    tertiary: r('tertiary'),
    onTertiary: r('on_tertiary'),
    tertiaryContainer: r('tertiary_container'),
    onTertiaryContainer: r('on_tertiary_container'),
    tertiaryFixed: r('tertiary_fixed'),
    tertiaryFixedDim: r('tertiary_fixed_dim'),
    onTertiaryFixed: r('on_tertiary_fixed'),
    onTertiaryFixedVariant: r('on_tertiary_fixed_variant'),
    error: r('error'),
    onError: r('on_error'),
    errorContainer: r('error_container'),
    onErrorContainer: r('on_error_container'),
    surface: r('surface'),
    onSurface: r('on_surface'),
    onSurfaceVariant: r('on_surface_variant'),
    surfaceDim: r('surface_dim'),
    surfaceBright: r('surface_bright'),
    surfaceContainerLowest: r('surface_container_lowest'),
    surfaceContainerLow: r('surface_container_low'),
    surfaceContainer: r('surface_container'),
    surfaceContainerHigh: r('surface_container_high'),
    surfaceContainerHighest: r('surface_container_highest'),
    outline: r('outline'),
    outlineVariant: r('outline_variant'),
    inverseSurface: r('inverse_surface'),
    onInverseSurface: r('inverse_on_surface'),
    scrim: r('scrim'),
    shadow: r('shadow'),
    surfaceTint: r('surface_tint'),
  );
}
