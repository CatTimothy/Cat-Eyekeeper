import 'dart:ui';

import 'domain/models/settings.dart';

/// Resolves the user's language setting to a concrete [Locale] — used by
/// app.dart (MaterialApp.locale) and main.dart (the tray's initial
/// locale). `system` follows the OS locale, matched against the app's
/// supported locales (falling back to English).
Locale resolveLocale(AppLanguage language) {
  switch (language) {
    case AppLanguage.en:
      return const Locale('en');
    case AppLanguage.zh:
      return const Locale('zh');
    case AppLanguage.zhHant:
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    case AppLanguage.system:
      return _resolveSystemLocale();
  }
}

Locale _resolveSystemLocale() {
  final systemLocale = PlatformDispatcher.instance.locale;
  if (systemLocale.languageCode != 'zh') return const Locale('en');

  final isTraditional =
      systemLocale.scriptCode == 'Hant' || const {'TW', 'HK', 'MO'}.contains(systemLocale.countryCode);
  return isTraditional ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant') : const Locale('zh');
}
