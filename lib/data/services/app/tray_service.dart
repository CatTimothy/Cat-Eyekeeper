import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../../data/repositories/app_paths.dart';
import '../../../domain/use_cases/tray_speed.dart';
import '../../../l10n/app_localizations.dart';
import 'tray_icons.dart';

const _trayIconAsset = 'assets/bundled_packs/tray_icon/star_cat/image.gif';

/// Wires the system tray: an icon animated at a CPU-driven speed, a
/// 3-item context menu, a status tooltip, and update-available
/// notifications. Functional spec section 4.
class TrayService with TrayListener {
  TrayService({required AppPaths paths, bool useDarkForeground = false, TrayIconFactory? iconFactory})
    : _paths = paths,
      _useDarkForeground = useDarkForeground,
      _iconFactory = iconFactory ?? const TrayIconFactory();

  final TrayIconFactory _iconFactory;
  final AppPaths _paths;

  final _openDashboardController = StreamController<void>.broadcast();
  final _openSettingsController = StreamController<void>.broadcast();
  final _exitController = StreamController<void>.broadcast();
  final _updateDownloadController = StreamController<void>.broadcast();

  Stream<void> get openDashboardRequested => _openDashboardController.stream;
  Stream<void> get openSettingsRequested => _openSettingsController.stream;
  Stream<void> get exitRequested => _exitController.stream;
  Stream<void> get updateDownloadRequested => _updateDownloadController.stream;

  AppLocalizations? _l10n;
  List<String>? _lightForegroundFrames;
  List<String>? _darkForegroundFrames;
  bool _useDarkForeground;
  Timer? _animationTimer;
  int _frameIndex = 0;
  bool _isPaused = false;
  double _cpuPercent = 0;

  Future<void> start({required Locale locale}) async {
    trayManager.addListener(this);
    await localNotifier.setup(appName: 'ScreenTimeFlutter');
    _l10n = await AppLocalizations.delegate.load(locale);

    await _loadFrames();

    // setIcon must run before setContextMenu: on Linux, tray_manager's
    // AppIndicator is only constructed inside its setIcon handler, and
    // setContextMenu calls app_indicator_set_menu() on it with no null
    // check, so calling menu-first crashes the assertion on startup.
    await _setFrame(0);
    await _applyMenu();
    _scheduleNextFrame();
  }

  Future<void> setLocale(Locale locale) async {
    _l10n = await AppLocalizations.delegate.load(locale);
    await _applyMenu();
  }

  Future<void> setTrayForeground({required bool useDarkForeground}) async {
    if (_useDarkForeground == useDarkForeground) return;
    _useDarkForeground = useDarkForeground;
    await _setFrame(_frameIndex);
  }

  /// Loads the bundled default tray icon's frames, falling back to the
  /// procedural neutral icon if that art can't be read.
  Future<void> _loadFrames() async {
    final iconPath = _paths.resolveBundledAsset(_trayIconAsset);
    final iconFrames = _iconFactory.buildFramesFromImagePath(iconPath);
    final List<Uint8List> lightFrames = iconFrames ?? [_iconFactory.buildDefaultIcon(useDarkForeground: false)];
    final List<Uint8List> darkFrames = iconFrames ?? [_iconFactory.buildDefaultIcon(useDarkForeground: true)];
    _lightForegroundFrames = await _iconFactory.writeFramesToTempFiles(lightFrames);
    _darkForegroundFrames = await _iconFactory.writeFramesToTempFiles(darkFrames);
  }

  void setPaused(bool paused) {
    _isPaused = paused;
    _scheduleNextFrame();
  }

  void setCpuUsagePercent(double percent) {
    _cpuPercent = percent;
    _scheduleNextFrame();
  }

  Future<void> updateTooltip({
    required bool isActive,
    required bool isPaused,
    required Duration today,
    required double cpuPercent,
  }) async {
    final l10n = _l10n;
    if (l10n == null) return;
    final status = isPaused ? l10n.trayStatusPaused : (isActive ? l10n.trayStatusActive : l10n.trayStatusIdle);
    final tooltip = l10n.trayTooltipSummary(status, _formatDuration(today), cpuPercent.toStringAsFixed(1));
    await trayManager.setToolTip(tooltip);
  }

  Future<void> showUpdateAvailable(String version) async {
    final l10n = _l10n;
    if (l10n == null) return;
    final notification = LocalNotification(
      title: l10n.trayUpdateAvailableTitle,
      body: l10n.trayUpdateAvailableBody(version),
    )..onClick = () => _updateDownloadController.add(null);
    await notification.show();
  }

  Future<void> _applyMenu() async {
    final l10n = _l10n;
    if (l10n == null) return;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'open_dashboard',
            label: l10n.trayOpenDashboard,
            onClick: (_) => _openDashboardController.add(null),
          ),
          MenuItem(key: 'settings', label: l10n.traySettings, onClick: (_) => _openSettingsController.add(null)),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: l10n.trayExit, onClick: (_) => _exitController.add(null)),
        ],
      ),
    );
  }

  void _scheduleNextFrame() {
    _animationTimer?.cancel();
    _animationTimer = Timer(trayTickInterval(_cpuPercent, isPaused: _isPaused), () async {
      final frameCount = _lightForegroundFrames?.length ?? TrayIconFactory.defaultFrameCount;
      _frameIndex = (_frameIndex + 1) % frameCount;
      await _setFrame(_frameIndex);
      _scheduleNextFrame();
    });
  }

  Future<void> _setFrame(int index) async {
    final frames = _useDarkForeground ? _darkForegroundFrames : _lightForegroundFrames;
    final path = frames?[index];
    if (path != null) {
      await trayManager.setIcon(path);
    }
  }

  @override
  void onTrayIconMouseDown() => _openDashboardController.add(null);

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h${minutes}m' : '${minutes}m';
  }

  Future<void> dispose() async {
    _animationTimer?.cancel();
    trayManager.removeListener(this);
    await trayManager.destroy();
    await _openDashboardController.close();
    await _openSettingsController.close();
    await _exitController.close();
    await _updateDownloadController.close();
  }
}
