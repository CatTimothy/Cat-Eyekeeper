import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'app_locale.dart';
import 'data/repositories/app_paths.dart';
import 'di/injection.dart';
import 'domain/models/settings.dart';
import 'data/services/app/app_logger.dart';
import 'data/services/app/single_instance_service.dart';
import 'theme/app_theme.dart';
import 'ui/core/view_models/settings_view_model.dart';
import 'ui/core/view_models/view_model_injection.dart';
import 'ui/shell/view_models/tray_coordinator.dart';

Future<void> main(List<String> args) async {
  final logger = AppLogger(paths: AppPaths());

  await runZonedGuarded(() async {
    // Must run inside this same zone as runApp() below — calling this
    // outside runZonedGuarded causes a "Zone mismatch" warning from the
    // framework since binding init and runApp would then disagree on
    // which zone owns zone-specific configuration.
    WidgetsFlutterBinding.ensureInitialized();
    // Registers fvp's native (mdk) video backend as video_player's platform
    // implementation — required once, before any VideoPlayerController is
    // created (reminder animation videos, see
    // ui/reminder/widgets/reminder_animation_player.dart). Unlike the
    // stock video_player backends, mdk decodes and composites a source
    // video's own alpha channel (VP8/VP9/HEVC), which is why the reminder
    // overlay can show transparent video art over the blurred desktop
    // backdrop.
    fvp.registerWith();

    FlutterError.onError = (details) {
      logger.log(details.exception, stackTrace: details.stack, context: 'FlutterError');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.log(error, stackTrace: stack, context: 'PlatformDispatcher');
      return true;
    };

    // `--startup` is passed by StartupService's autostart entry (launch at
    // login) — start hidden to the tray instead of popping the dashboard.
    final startedHidden = args.contains('--startup');

    // windowManager registration and the single-instance claim touch
    // entirely disjoint state, so run them concurrently rather than paying
    // their latency serially.
    final singleInstance = SingleInstanceService();
    final (_, isPrimaryInstance) = await (windowManager.ensureInitialized(), singleInstance.claim()).wait;
    if (!isPrimaryInstance) {
      // Another instance is already running and has just been pinged (see
      // SingleInstanceService) to show itself instead — nothing left for
      // this launch to do. Bail out before configureDependencies() touches
      // any on-disk state, so there's never a second TrackingEngine
      // writing the same usage file.
      return;
    }

    await configureDependencies(singleInstance: singleInstance);
    configureViewModels(getIt);
    await getIt<AppLifecycle>().start();
    // Started here rather than reactively from ui/shell/app_shell.dart's
    // build() (the old trayStartupProvider) — nothing about bringing the
    // tray icon up depends on the widget tree existing yet, so it can
    // start as soon as settings are loaded.
    await getIt<TrayCoordinator>().start(
      locale: resolveLocale(getIt<SettingsViewModel>().current.language),
    );

    // Match the initial native window transparency to the persisted theme
    // so there's no opaque/transparent flash on the first frame — later
    // theme changes are handled live by ui/shell/app_shell.dart instead.
    final initialSettings = getIt<Settings>(instanceName: initialSettingsInstanceName);
    final startsTransparent = themeRequiresTransparentWindow(initialSettings.themeMode, initialSettings.customThemeColors);
    final windowOptions = WindowOptions(
      size: const Size(1100, 720),
      // Low enough to reach common phone widths (~360-414 logical px) —
      // every screen has a responsive breakpoint at that width (see
      // ui/responsive.dart) so the window stays usable resized all the
      // way down, not just at desktop sizes.
      minimumSize: const Size(360, 600),
      center: true,
      backgroundColor: startsTransparent ? Colors.transparent : Colors.black,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    // Closing the window hides it to the tray instead of quitting — see
    // ui/shell/app_shell.dart's WindowListener, which is the only place
    // that flips this back off (for the tray's "Exit" action).
    await windowManager.setPreventClose(true);
    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (!startedHidden) {
          await windowManager.show();
          await windowManager.focus();
        }
      }),
    );

    runApp(const ScreenTimeApp());
  }, (error, stack) => logger.log(error, stackTrace: stack, context: 'runZonedGuarded'));
}
