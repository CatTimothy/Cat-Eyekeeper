import 'package:flutter/material.dart';

import '../domain/models/settings.dart';
import 'app_colors.dart';
import 'glass_theme.dart';

/// Builds the app's [ThemeData], switching on [mode] rather than a
/// scattered set of boolean/nullable parameters — every mode's default
/// colors live in exactly one branch here. `custom` only matters for
/// [AppThemeMode.custom] (falls back to [CustomThemeColors.defaults] if
/// omitted); every other mode ignores it.
ThemeData buildAppTheme({required AppThemeMode mode, required Brightness brightness, CustomThemeColors? custom}) {
  switch (mode) {
    case AppThemeMode.custom:
      return _buildCustomTheme(custom ?? CustomThemeColors.defaults());
    case AppThemeMode.glass:
      return _buildGlassTheme(brightness);
    case AppThemeMode.system:
    case AppThemeMode.light:
    case AppThemeMode.dark:
      return _buildStandardTheme(brightness);
  }
}

ThemeData _buildStandardTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(seedColor: brandSeedColor, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
  );
}

ThemeData _buildCustomTheme(CustomThemeColors custom) {
  final backgroundBase = colorFromHex(custom.backgroundColorHex);
  final widgetsBase = colorFromHex(custom.widgetsColorHex);
  final accent = colorFromHex(custom.accentColorHex);
  final textColor = colorFromHex(custom.textColorHex);

  final backgroundColor = backgroundBase.withValues(alpha: custom.backgroundOpacity);
  final widgetsColor = widgetsBase.withValues(alpha: custom.widgetsOpacity);
  final brightness = ThemeData.estimateBrightnessForColor(backgroundBase);

  final colorScheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
    surface: widgetsColor,
    primary: accent,
    onSurface: textColor,
    onSurfaceVariant: textColor,
  );

  // Most Text widgets read Theme.textTheme directly rather than
  // colorScheme.onSurface, so the user's text color has to be applied
  // there too, not just on the ColorScheme.
  final textTheme = ThemeData(brightness: brightness).textTheme.apply(bodyColor: textColor, displayColor: textColor);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: widgetsColor,
    textTheme: textTheme,
  );
}

/// `glass` has no user-facing opacity slider (unlike `custom`) — it always
/// ships at this fixed window alpha, baked directly into
/// [_glassBackgroundGradient]'s colors rather than being configurable.
const _glassWindowOpacity = 0.55;

/// [GlassTheme.surfaceColor]/[GlassTheme.borderColor]/blur sigma, plus the
/// gradient app_shell.dart paints behind the whole window in place of a
/// flat `scaffoldBackgroundColor` — see glass_theme.dart for why a flat
/// color alone wouldn't give [GlassSurface]'s `BackdropFilter` panels
/// anything real to blur.
ThemeData _buildGlassTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(seedColor: brandSeedColor, brightness: brightness);

  final gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? [
            const Color(0xFF1B1036).withValues(alpha: _glassWindowOpacity),
            const Color(0xFF0E1630).withValues(alpha: _glassWindowOpacity),
            const Color(0xFF17243F).withValues(alpha: _glassWindowOpacity),
          ]
        : [
            const Color(0xFFEAF0FF).withValues(alpha: _glassWindowOpacity),
            const Color(0xFFF3E9FF).withValues(alpha: _glassWindowOpacity),
            const Color(0xFFE6F7F3).withValues(alpha: _glassWindowOpacity),
          ],
  );

  final surfaceColor = dark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.45);
  final borderColor = dark ? Colors.white.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.65);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme.copyWith(surface: surfaceColor),
    scaffoldBackgroundColor: dark ? const Color(0xFF14152A).withValues(alpha: _glassWindowOpacity) : const Color(0xFFEEF0FA).withValues(alpha: _glassWindowOpacity),
    cardColor: surfaceColor,
    extensions: [GlassTheme(backgroundGradient: gradient, surfaceColor: surfaceColor, borderColor: borderColor, blurSigma: 24)],
  );
}

/// Whether the native OS window itself needs to be translucent for this
/// theme to render correctly — true for custom mode when the user set
/// background opacity below 1.0, and always true for `glass`. Every other
/// mode renders as a fully opaque window (see ui/shell/app_shell.dart).
bool themeRequiresTransparentWindow(AppThemeMode mode, CustomThemeColors? custom) {
  switch (mode) {
    case AppThemeMode.custom:
      return (custom ?? CustomThemeColors.defaults()).backgroundOpacity < 1.0;
    case AppThemeMode.glass:
      return true;
    case AppThemeMode.system:
    case AppThemeMode.light:
    case AppThemeMode.dark:
      return false;
  }
}
