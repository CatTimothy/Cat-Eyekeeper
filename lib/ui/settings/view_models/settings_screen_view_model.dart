import '../../../di/injection.dart';
import '../../../domain/models/settings.dart';
import '../../core/base_view_model.dart';
import '../../core/view_models/settings_view_model.dart';

/// A working copy of [SettingsViewModel.current] for the settings screen
/// to edit without touching the persisted value until Save. Screen-scoped
/// (get_it `registerFactory` — a fresh instance every time the settings
/// screen is shown), which structurally replaces the old
/// `SettingsDraftController.reset()` — Riverpod kept that notifier's
/// state alive across navigations, requiring an explicit reset call on
/// every entry; a factory-scoped ViewModel simply starts fresh from
/// [SettingsViewModel.current] every time one is constructed, so there is
/// nothing to remember to reset.
class SettingsScreenViewModel extends BaseViewModel {
  SettingsScreenViewModel({SettingsViewModel? settingsViewModel})
    : _settingsViewModel = settingsViewModel ?? getIt<SettingsViewModel>(),
      _draft = (settingsViewModel ?? getIt<SettingsViewModel>()).current;

  final SettingsViewModel _settingsViewModel;

  Settings _draft;
  Settings get draft => _draft;

  void update(Settings Function(Settings draft) updater) {
    _draft = updater(_draft);
    safeNotifyListeners();
  }

  /// Applies [updater] to both the draft (so the screen reflects it
  /// immediately) and the persisted settings (via [SettingsViewModel]) —
  /// for controls that save live rather than waiting for the screen's
  /// Save button (theme mode, custom theme colors). Persists against the
  /// live settings, not the draft, so any other unsaved edits elsewhere
  /// on the screen aren't accidentally persisted early.
  Future<void> saveImmediately(Settings Function(Settings settings) updater) async {
    _draft = updater(_draft);
    safeNotifyListeners();
    await _settingsViewModel.save(updater(_settingsViewModel.current));
  }

  /// Persists [settings] (the caller's draft, possibly further amended —
  /// see ui/settings/settings_screen.dart's `_save`, which applies the
  /// validated number-field values on top of the draft first) via
  /// [SettingsViewModel].
  Future<void> save(Settings settings) => _settingsViewModel.save(settings);
}
