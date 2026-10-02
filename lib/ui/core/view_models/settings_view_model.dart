import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/app/startup_service.dart';
import '../../../di/injection.dart';
import '../../../domain/models/settings.dart';
import '../../../domain/use_cases/reminder_scheduler.dart';
import '../../../domain/use_cases/tracking_engine.dart';
import '../base_view_model.dart';

/// The persisted settings — a single get_it singleton, shared by every
/// feature that reads or saves them (Settings screen, tray coordinator,
/// theme, locale, reminder). [save] writes to disk and pushes the new
/// value out to every service that depends on it (tracking engine's idle
/// threshold, reminder scheduler, launch-at-startup); everything else
/// just reacts to this ViewModel's own change notifications via
/// `ListenableBuilder`.
class SettingsViewModel extends BaseViewModel {
  SettingsViewModel({
    Settings? initialSettings,
    SettingsRepository? settingsRepository,
    TrackingEngine? trackingEngine,
    ReminderScheduler? reminderScheduler,
    StartupService? startupService,
  }) : _settingsRepository = settingsRepository ?? getIt<SettingsRepository>(),
       _trackingEngine = trackingEngine ?? getIt<TrackingEngine>(),
       _reminderScheduler = reminderScheduler ?? getIt<ReminderScheduler>(),
       _startupService = startupService ?? getIt<StartupService>(),
       _current = initialSettings ?? getIt<Settings>(instanceName: initialSettingsInstanceName);

  final SettingsRepository _settingsRepository;
  final TrackingEngine _trackingEngine;
  final ReminderScheduler _reminderScheduler;
  final StartupService _startupService;

  Settings _current;
  Settings get current => _current;

  Future<void> save(Settings settings) async {
    await _settingsRepository.save(settings);
    _current = settings;

    _trackingEngine.updateSettings(settings);
    _reminderScheduler.updateSettings(settings);
    await _startupService.apply(settings.launchAtStartup);
    safeNotifyListeners();
  }
}
