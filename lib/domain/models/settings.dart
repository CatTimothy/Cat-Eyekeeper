import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// Software theme, independently named from Flutter's own `ThemeMode` to
/// avoid ambiguity when both are in scope (see services/theme_service.dart).
/// `glass` is unrelated to the old `liquid_glass` value a persisted
/// Settings file might still carry (see [appThemeModeFromJson]) — that
/// mode relied on native OS blur-behind and was removed outright; `glass`
/// is a from-scratch, cross-platform Flutter-rendered frosted-glass look
/// (theme/glass_theme.dart) with no relation to the old implementation,
/// so a stale `liquid_glass` value deliberately does not resolve to it.
enum AppThemeMode { system, light, dark, custom, glass }

const Map<AppThemeMode, String> _themeModeJsonValues = {
  AppThemeMode.system: 'system',
  AppThemeMode.light: 'light',
  AppThemeMode.dark: 'dark',
  AppThemeMode.custom: 'custom',
  AppThemeMode.glass: 'glass',
};

String appThemeModeToJson(AppThemeMode mode) => _themeModeJsonValues[mode]!;

AppThemeMode appThemeModeFromJson(String value) => _themeModeJsonValues.entries
    .firstWhere((e) => e.value == value, orElse: () => const MapEntry(AppThemeMode.system, 'system'))
    .key;

/// User-picked colors for [AppThemeMode.custom]. Colors are stored as
/// `#RRGGBB` hex strings rather than Flutter's `Color` — this file must
/// stay pure Dart (no `package:flutter`); hex<->Color conversion lives in
/// theme/app_colors.dart, which is allowed to depend on Flutter.
@freezed
abstract class CustomThemeColors with _$CustomThemeColors {
  const factory CustomThemeColors({
    required String backgroundColorHex,

    /// 0.0-1.0. Below 1.0 makes the native window itself translucent (see
    /// ui/shell/app_shell.dart), not just the Flutter content.
    required double backgroundOpacity,
    required String widgetsColorHex,
    required double widgetsOpacity,
    required String accentColorHex,

    // `textColorHex` defaults to opaque white when reading settings saved
    // before this field existed — a JSON-only fallback (still required for
    // direct/non-JSON construction, unlike the `@Default`-annotated fields
    // elsewhere in this file, which default both ways).
    @JsonKey(defaultValue: '#FFFFFF') required String textColorHex,
  }) = _CustomThemeColors;

  factory CustomThemeColors.fromJson(Map<String, dynamic> json) => _$CustomThemeColorsFromJson(json);

  /// A `static` method rather than a named factory constructor — freezed's
  /// code generator only special-cases named `factory` redirects (used for
  /// union types), and this is a plain helper, not another constructor.
  static CustomThemeColors defaults() => const CustomThemeColors(
    backgroundColorHex: '#12121A',
    backgroundOpacity: 1.0,
    widgetsColorHex: '#1E1E2A',
    widgetsOpacity: 0.9,
    accentColorHex: '#4C6FFF',
    textColorHex: '#FFFFFF',
  );
}

/// Display language. `system` follows the OS locale at runtime.
enum AppLanguage { system, zh, zhHant, en }

const Map<AppLanguage, String> _languageJsonValues = {
  AppLanguage.system: 'system',
  AppLanguage.zh: 'zh',
  AppLanguage.zhHant: 'zh_hant',
  AppLanguage.en: 'en',
};

String appLanguageToJson(AppLanguage language) => _languageJsonValues[language]!;

AppLanguage appLanguageFromJson(String value) => _languageJsonValues.entries
    .firstWhere((e) => e.value == value, orElse: () => const MapEntry(AppLanguage.system, 'system'))
    .key;

/// User-configurable settings (functional spec section 6). Persisted as a
/// single JSON object by data/settings_repository.dart. The settings screen
/// edits a draft copy and only calls the repository on Save — see
/// ui/settings/view_models/settings_screen_view_model.dart.
@freezed
abstract class Settings with _$Settings {
  const factory Settings({
    @Default(1) int version,

    required bool reminderEnabled,
    required bool allowCloseFullscreenReminder,

    /// 1-240.
    required int reminderIntervalMinutes,

    /// 1-60.
    required int breakDurationMinutes,

    /// 10-3600.
    required int idleThresholdSeconds,

    @JsonKey(fromJson: appThemeModeFromJson, toJson: appThemeModeToJson) required AppThemeMode themeMode,

    /// Only meaningful when [themeMode] is [AppThemeMode.custom]; null falls
    /// back to [CustomThemeColors.defaults] wherever it's read.
    @JsonKey(includeIfNull: false) CustomThemeColors? customThemeColors,

    @JsonKey(fromJson: appLanguageFromJson, toJson: appLanguageToJson) required AppLanguage language,

    /// 0.0-1.0.
    required double overlayBlurStrength,

    required bool trayReminderAnimationEnabled,
    required bool launchAtStartup,
  }) = _Settings;

  factory Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);

  /// A `static` method rather than a named factory constructor — freezed's
  /// code generator only special-cases named `factory` redirects (used for
  /// union types), and this is a plain helper, not another constructor.
  static Settings defaults() => const Settings(
    reminderEnabled: true,
    allowCloseFullscreenReminder: false,
    reminderIntervalMinutes: 45,
    breakDurationMinutes: 3,
    idleThresholdSeconds: 60,
    themeMode: AppThemeMode.system,
    language: AppLanguage.system,
    overlayBlurStrength: 0.3,
    trayReminderAnimationEnabled: true,
    launchAtStartup: true,
  );
}
