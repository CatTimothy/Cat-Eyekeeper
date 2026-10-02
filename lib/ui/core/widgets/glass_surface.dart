import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/glass_theme.dart';

/// Drop-in replacement for a plain [Card] panel, used by every major
/// surface (ui/settings/widgets/settings_group.dart,
/// ui/dashboard/widgets/stat_card.dart, ui/dashboard/dashboard_screen.dart's
/// `_ChartCard`/`_AppListCard`) so [AppThemeMode.glass] gets a frosted
/// BackdropFilter panel everywhere a card already appears, with zero
/// behavior change for every other theme: when the current [ThemeData] has
/// no [GlassTheme] extension (every mode except `glass`), this renders a
/// plain [Card] identical to what each call site used directly before.
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.padding, this.margin, this.borderRadius});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<GlassTheme>();
    final content = padding == null ? child : Padding(padding: padding!, child: child);

    if (glass == null) {
      return Card(
        margin: margin,
        shape: borderRadius == null ? null : RoundedRectangleBorder(borderRadius: borderRadius!),
        child: content,
      );
    }

    final radius = borderRadius ?? BorderRadius.circular(12);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: glass.blurSigma, sigmaY: glass.blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: glass.surfaceColor,
              borderRadius: radius,
              border: Border.all(color: glass.borderColor),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
