import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/models/settings.dart';
import 'package:cat_eyekeeper/theme/app_theme.dart';
import 'package:cat_eyekeeper/theme/glass_theme.dart';

void main() {
  group('themeRequiresTransparentWindow', () {
    test('system/light/dark never require a transparent window', () {
      expect(themeRequiresTransparentWindow(AppThemeMode.system, null), isFalse);
      expect(themeRequiresTransparentWindow(AppThemeMode.light, null), isFalse);
      expect(themeRequiresTransparentWindow(AppThemeMode.dark, null), isFalse);
    });

    test('custom mode requires transparency only when background opacity < 1', () {
      final opaque = CustomThemeColors.defaults().copyWith(backgroundOpacity: 1.0);
      final translucent = CustomThemeColors.defaults().copyWith(backgroundOpacity: 0.5);

      expect(themeRequiresTransparentWindow(AppThemeMode.custom, opaque), isFalse);
      expect(themeRequiresTransparentWindow(AppThemeMode.custom, translucent), isTrue);
    });

    test('custom mode with no colors set falls back to defaults (opaque)', () {
      expect(themeRequiresTransparentWindow(AppThemeMode.custom, null), isFalse);
    });

    test('glass always requires a transparent window', () {
      expect(themeRequiresTransparentWindow(AppThemeMode.glass, null), isTrue);
    });
  });

  group('buildAppTheme', () {
    test('system/light/dark modes use an opaque scaffold background', () {
      for (final mode in [AppThemeMode.system, AppThemeMode.light, AppThemeMode.dark]) {
        final theme = buildAppTheme(mode: mode, brightness: Brightness.dark);
        expect(theme.scaffoldBackgroundColor.a, 1, reason: '$mode');
      }
    });

    test('custom mode applies the configured background opacity', () {
      final custom = CustomThemeColors.defaults().copyWith(backgroundOpacity: 0.4);
      final theme = buildAppTheme(mode: AppThemeMode.custom, brightness: Brightness.dark, custom: custom);
      expect(theme.scaffoldBackgroundColor.a, closeTo(0.4, 0.01));
    });

    test('custom mode with no colors falls back to defaults', () {
      final theme = buildAppTheme(mode: AppThemeMode.custom, brightness: Brightness.dark);
      expect(theme.scaffoldBackgroundColor.a, 1);
    });

    test('custom mode applies the configured text color', () {
      final custom = CustomThemeColors.defaults().copyWith(textColorHex: '#FF0000');
      final theme = buildAppTheme(mode: AppThemeMode.custom, brightness: Brightness.dark, custom: custom);
      expect(theme.colorScheme.onSurface, const Color(0xFFFF0000));
      expect(theme.textTheme.bodyMedium!.color, const Color(0xFFFF0000));
    });

    test('glass mode is translucent and carries a GlassTheme extension for both brightnesses', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final theme = buildAppTheme(mode: AppThemeMode.glass, brightness: brightness);
        expect(theme.scaffoldBackgroundColor.a, lessThan(1), reason: '$brightness');

        final glass = theme.extension<GlassTheme>();
        expect(glass, isNotNull, reason: '$brightness');
        expect(glass!.surfaceColor.a, lessThan(1), reason: '$brightness');
        expect(glass.blurSigma, greaterThan(0), reason: '$brightness');
      }
    });
  });
}
