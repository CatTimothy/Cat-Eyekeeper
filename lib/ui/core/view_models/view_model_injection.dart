import 'package:get_it/get_it.dart';

import '../../../data/services/app/update_service.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../reminder/view_models/reminder_view_model.dart';
import '../../settings/view_models/settings_screen_view_model.dart';
import '../../shell/view_models/tray_coordinator.dart';
import 'dashboard_status_visibility.dart';
import 'settings_view_model.dart';
import 'update_check_view_model.dart';

/// Registers every ViewModel as a get_it registration — kept out of
/// di/injection.dart's `configureDependencies()` deliberately: that file
/// constructs domain/data/service objects only and must never import from
/// ui/ (di/ sits below ui/ in the dependency direction). Called from
/// main.dart, which — as the composition root — is free to import both.
///
/// `registerSingleton` for shared, cross-feature ViewModels (one instance
/// for the app's whole lifetime — e.g. [UpdateCheckViewModel], shown on
/// both About and Settings). `registerFactory` for screen-scoped
/// ViewModels (a fresh instance every time the owning screen resolves
/// one — e.g. [DashboardViewModel], which reloads from disk on
/// construction, so a screen that's freshly (re)shown always reflects the
/// current on-disk state with no separate "invalidate" step needed).
void configureViewModels(GetIt getIt) {
  getIt.registerSingleton<UpdateCheckViewModel>(UpdateCheckViewModel(updateService: getIt<UpdateService>()));
  getIt.registerSingleton<SettingsViewModel>(SettingsViewModel());
  getIt.registerSingleton<DashboardStatusVisibility>(DashboardStatusVisibility());
  getIt.registerSingleton<TrayCoordinator>(TrayCoordinator());
  getIt.registerFactory<DashboardViewModel>(DashboardViewModel.new);
  getIt.registerFactory<SettingsScreenViewModel>(SettingsScreenViewModel.new);
  getIt.registerFactory<ReminderViewModel>(ReminderViewModel.new);
}
