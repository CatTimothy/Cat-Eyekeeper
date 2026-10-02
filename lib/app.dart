import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'data/services/app/theme_service.dart';
import 'di/injection.dart';
import 'l10n/app_localizations.dart';
import 'ui/core/view_models/settings_view_model.dart';
import 'ui/shell/app_shell.dart';

class ScreenTimeApp extends StatelessWidget {
  /// [home] defaults to the real [AppShell]; tests can override it to
  /// avoid exercising window_manager/tray_manager/local_notifier's native
  /// platform channels, which aren't backed by real plugins under
  /// `flutter test` (only under a real `flutter run`).
  const ScreenTimeApp({super.key, this.home = const AppShell()});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    final settingsViewModel = getIt<SettingsViewModel>();
    return ListenableBuilder(
      listenable: settingsViewModel,
      builder: (context, _) {
        final settings = settingsViewModel.current;
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: resolveLocale(settings.language),
          theme: getIt<ThemeService>().themeData(settings.themeMode, customColors: settings.customThemeColors),
          home: home,
        );
      },
    );
  }
}
