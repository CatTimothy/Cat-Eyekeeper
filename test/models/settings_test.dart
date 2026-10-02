import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/models/settings.dart';

void main() {
  test('Settings round-trips through JSON', () {
    final original = Settings.defaults().copyWith(
      reminderIntervalMinutes: 90,
      themeMode: AppThemeMode.dark,
      language: AppLanguage.zhHant,
      overlayBlurStrength: 0.75,
    );

    final decoded = Settings.fromJson(original.toJson());

    expect(decoded.reminderIntervalMinutes, 90);
    expect(decoded.themeMode, AppThemeMode.dark);
    expect(decoded.language, AppLanguage.zhHant);
    expect(decoded.overlayBlurStrength, 0.75);
  });

  test('enum JSON values are stable strings, not Dart enum names', () {
    expect(appThemeModeToJson(AppThemeMode.dark), 'dark');
    expect(appThemeModeToJson(AppThemeMode.glass), 'glass');
    expect(appLanguageToJson(AppLanguage.zhHant), 'zh_hant');
    expect(appThemeModeFromJson('dark'), AppThemeMode.dark);
    expect(appThemeModeFromJson('glass'), AppThemeMode.glass);
  });

  test('unknown enum JSON values fall back to a safe default', () {
    expect(appThemeModeFromJson('not_a_real_mode'), AppThemeMode.system);
    expect(appLanguageFromJson('klingon'), AppLanguage.system);
  });

  test('a previously persisted liquid_glass theme (now removed) falls back to system', () {
    expect(appThemeModeFromJson('liquid_glass'), AppThemeMode.system);
  });
}
