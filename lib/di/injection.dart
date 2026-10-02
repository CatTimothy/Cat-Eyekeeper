import 'package:get_it/get_it.dart';

import '../domain/use_cases/category_classifier.dart';
import '../domain/use_cases/cpu_monitor.dart';
import '../domain/use_cases/idle_detector.dart';
import '../domain/use_cases/reminder_scheduler.dart';
import '../domain/use_cases/tracking_engine.dart';
import '../data/repositories/app_paths.dart';
import '../data/repositories/category_rule_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/usage_repository.dart';
import '../domain/models/category_rule.dart';
import '../domain/models/settings.dart';
import '../data/services/platform/platform_factory.dart';
import '../data/services/app/app_logger.dart';
import '../data/services/app/desktop_backdrop_service.dart';
import '../data/services/app/single_instance_service.dart';
import '../data/services/app/startup_service.dart';
import '../data/services/app/theme_service.dart';
import '../data/services/app/tray_service.dart';
import '../data/services/app/update_service.dart';
import '../data/services/app/window_shell.dart';

// TODO: point this at the GitHub repo this app is actually released from
// before shipping — see services/update_service.dart.
const _updateCheckRepoOwner = 'YOUR_GITHUB_OWNER';
const _updateCheckRepoName = 'YOUR_GITHUB_REPO';

/// The `instanceName` [initialSettings] is registered under — distinct from
/// the plain `Settings` type so a later live/current-settings registration
/// (see ui/core/view_models/settings_view_model.dart) can never collide
/// with this one-shot startup snapshot.
const initialSettingsInstanceName = 'initialSettings';

final getIt = GetIt.instance;

/// Constructs every repository/service/engine the app needs exactly once,
/// before the widget tree exists, and registers each as a get_it singleton
/// — the direct replacement for the old `AppBootstrap` object. Call once
/// from main.dart, before `runApp`.
Future<void> configureDependencies({AppPaths? paths, SingleInstanceService? singleInstance}) async {
  final resolvedPaths = paths ?? AppPaths();
  final settingsRepository = SettingsRepository(paths: resolvedPaths);
  final usageRepository = UsageRepository(paths: resolvedPaths);
  final categoryRuleRepository = CategoryRuleRepository(paths: resolvedPaths);

  final (settings, todayUsage, categoryRules) = await (
    settingsRepository.load(),
    usageRepository.loadToday(),
    categoryRuleRepository.load(),
  ).wait;

  final platformServices = PlatformServices.forCurrentPlatform();
  final desktopBackdropService = DesktopBackdropService(desktopCaptureReader: platformServices.desktopCaptureReader);
  final idleDetector = IdleDetector([platformServices.hidReader, platformServices.gamepadReader]);
  final classifier = CategoryClassifier(categoryRules);

  final trackingEngine = TrackingEngine(
    idleDetector: idleDetector,
    foregroundReader: platformServices.foregroundReader,
    classifier: classifier,
    usageRepository: usageRepository,
    settings: settings,
    initialUsage: todayUsage,
  );
  final reminderScheduler = ReminderScheduler(settings: settings);
  // Every usage snapshot feeds the reminder scheduler — wired once, for
  // the lifetime of the app, so no UI code needs to remember to do this.
  trackingEngine.snapshots.listen(reminderScheduler.observe);

  getIt
    ..registerSingleton<AppPaths>(resolvedPaths)
    ..registerSingleton<SettingsRepository>(settingsRepository)
    ..registerSingleton<UsageRepository>(usageRepository)
    ..registerSingleton<CategoryRuleRepository>(categoryRuleRepository)
    ..registerSingleton<DesktopBackdropService>(desktopBackdropService)
    ..registerSingleton<Settings>(settings, instanceName: initialSettingsInstanceName)
    ..registerSingleton<CategoryRules>(categoryRules)
    ..registerSingleton<PlatformServices>(platformServices)
    ..registerSingleton<TrackingEngine>(trackingEngine)
    ..registerSingleton<CpuMonitor>(CpuMonitor(reader: platformServices.cpuReader))
    ..registerSingleton<ReminderScheduler>(reminderScheduler)
    ..registerSingleton<TrayService>(TrayService(paths: resolvedPaths))
    ..registerSingleton<WindowShell>(WindowShell())
    ..registerSingleton<ThemeService>(const ThemeService())
    ..registerSingleton<StartupService>(const StartupService())
    ..registerSingleton<UpdateService>(UpdateService(repoOwner: _updateCheckRepoOwner, repoName: _updateCheckRepoName))
    ..registerSingleton<AppLogger>(AppLogger(paths: resolvedPaths))
    ..registerSingleton<AppLifecycle>(AppLifecycle());

  if (singleInstance != null) getIt.registerSingleton<SingleInstanceService>(singleInstance);
}

/// Startup/teardown for everything [configureDependencies] registered that
/// needs an explicit lifecycle beyond construction — the direct replacement
/// for `AppBootstrap.start()`/`.dispose()`.
class AppLifecycle {
  Future<void> start() async {
    getIt<StartupService>().setup();
    getIt<TrackingEngine>().start();
    getIt<CpuMonitor>().start();
  }

  Future<void> dispose() async {
    await getIt<TrackingEngine>().dispose();
    await getIt<CpuMonitor>().dispose();
    await getIt<ReminderScheduler>().dispose();
    await getIt<TrayService>().dispose();
    await getIt<WindowShell>().dispose();
    getIt<UpdateService>().dispose();
    await getIt<PlatformServices>().gamepadReader.dispose();
    if (getIt.isRegistered<SingleInstanceService>()) {
      await getIt<SingleInstanceService>().dispose();
    }
  }
}
