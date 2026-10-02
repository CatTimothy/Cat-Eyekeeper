import 'package:flutter/material.dart';

import '../domain/models/app_category.dart';

/// The app's brand seed color, used to generate the Material 3
/// [ColorScheme] for both light and dark themes.
const Color brandSeedColor = Colors.indigo;

/// Fixed color per usage category, used by the dashboard's chart and
/// legend (functional spec section 5). Deliberately independent of the
/// theme's brand color so category colors stay stable and
/// distinguishable across every theme mode (light/dark/glass).
const Map<AppCategory, Color> categoryColors = {
  AppCategory.work: Colors.indigo,
  AppCategory.social: Colors.teal,
  AppCategory.entertainment: Colors.deepOrange,
  AppCategory.learning: Colors.purple,
  AppCategory.system: Colors.blueGrey,
  AppCategory.other: Colors.grey,
};

/// Parses a `#RRGGBB` or `#AARRGGBB` hex string (as stored in
/// [CustomThemeColors]) into a [Color]. Falls back to opaque black on a
/// malformed string rather than throwing — this reads user-editable
/// settings data.
Color colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final value = int.tryParse(withAlpha, radix: 16);
  return value == null ? const Color(0xFF000000) : Color(value);
}

/// Formats a [Color] back to `#RRGGBB` (alpha is handled separately via
/// [CustomThemeColors]'s own opacity fields, not encoded here).
String colorToHex(Color color) {
  int channel(double c) => (c * 255).round().clamp(0, 255);
  final r = channel(color.r).toRadixString(16).padLeft(2, '0');
  final g = channel(color.g).toRadixString(16).padLeft(2, '0');
  final b = channel(color.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}
