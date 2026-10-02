import 'package:flutter/material.dart';

/// Extra styling [AppThemeMode.glass] attaches to [ThemeData.extensions] —
/// `ThemeData` itself has no notion of "blur a panel", so this is how
/// ui/core/widgets/glass_surface.dart finds out it should render a frosted
/// BackdropFilter panel instead of a plain [Card], and how
/// ui/shell/app_shell.dart finds out it should paint [backgroundGradient]
/// behind the window's content instead of a flat color. Absent (null via
/// `Theme.of(context).extension<GlassTheme>()`) for every other theme mode,
/// so those render exactly as before this existed.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  const GlassTheme({
    required this.backgroundGradient,
    required this.surfaceColor,
    required this.borderColor,
    required this.blurSigma,
  });

  /// Painted behind the whole window's content in place of a flat
  /// `scaffoldBackgroundColor` fill — see app_shell.dart's `build`. Gives
  /// [GlassSurface]'s `BackdropFilter` panels actual pixel detail to blur;
  /// blurring a flat color is a visual no-op.
  final Gradient backgroundGradient;

  /// Fill color for a frosted panel (GlassSurface) — translucent so the
  /// blurred [backgroundGradient] still shows through, tinted.
  final Color surfaceColor;

  /// A thin, slightly brighter edge around a frosted panel — the
  /// highlight that reads as "glass" rather than just a translucent
  /// rectangle.
  final Color borderColor;

  /// `ImageFilter.blur`'s sigma for a frosted panel's backdrop blur.
  final double blurSigma;

  @override
  GlassTheme copyWith({Gradient? backgroundGradient, Color? surfaceColor, Color? borderColor, double? blurSigma}) {
    return GlassTheme(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      borderColor: borderColor ?? this.borderColor,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return GlassTheme(
      backgroundGradient: Gradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
    );
  }
}
