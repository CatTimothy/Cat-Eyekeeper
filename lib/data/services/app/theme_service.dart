import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../domain/models/settings.dart';
import '../../../theme/app_theme.dart';

/// Resolves a user-selected [AppThemeMode] into a concrete [Brightness]
/// and [ThemeData]. `system` (and `glass`) follow the OS; `custom` uses
/// the user's own [CustomThemeColors] instead of a brightness-derived
/// palette.
class ThemeService {
  const ThemeService();

  Brightness resolveBrightness(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.custom:
        // Irrelevant for custom — buildAppTheme derives brightness from
        // the custom background color's own luminance instead.
        return Brightness.dark;
      case AppThemeMode.system:
      case AppThemeMode.glass:
        return PlatformDispatcher.instance.platformBrightness;
    }
  }

  ThemeData themeData(AppThemeMode mode, {CustomThemeColors? customColors}) =>
      buildAppTheme(mode: mode, brightness: resolveBrightness(mode), custom: customColors);

  /// Whether the native window needs to be translucent for [mode] to
  /// render correctly (custom with background opacity < 1) — see
  /// ui/shell/app_shell.dart.
  bool requiresTransparentWindow(AppThemeMode mode, CustomThemeColors? customColors) =>
      themeRequiresTransparentWindow(mode, customColors);
}
