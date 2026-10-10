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
class TrayService {
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
  TrayIcon? _trayIcon;
  ListenerId? _trayListenerId;
  Menu? _menu;
  List<MenuItem> _menuItems = const [];
  List<Image> _lightForegroundFrames = const [];
  List<Image> _darkForegroundFrames = const [];
  bool _useDarkForeground;
  Timer? _animationTimer;
  int _frameIndex = 0;
  bool _isPaused = false;
  double _cpuPercent = 0;

  Future<void> start({required Locale locale}) async {
    final trayIcon = TrayIcon.create();
    if (trayIcon == null) throw StateError('Unable to create the tray icon');
    _trayIcon = trayIcon;
    // Left click opens the dashboard (see _onTrayIconEvent); the native
    // layer pops the context menu on right click by itself. Linux reports
    // no tray clicks at all — the panel opens the menu on any click.
    trayIcon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    _trayListenerId = trayIcon.addListener(_onTrayIconEvent);

    await localNotifier.setup(appName: 'ScreenTimeFlutter');
    _l10n = await AppLocalizations.delegate.load(locale);

    await _loadFrames();

    _setFrame(0);
    trayIcon.setVisible(true);
    _applyMenu();
    _scheduleNextFrame();
  }

  Future<void> setLocale(Locale locale) async {
    _l10n = await AppLocalizations.delegate.load(locale);
    _applyMenu();
  }

  Future<void> setTrayForeground({required bool useDarkForeground}) async {
    if (_useDarkForeground == useDarkForeground) return;
    _useDarkForeground = useDarkForeground;
    _setFrame(_frameIndex);
  }

  /// Loads the bundled default tray icon's frames, falling back to the
  /// procedural neutral icon if that art can't be read.
  Future<void> _loadFrames() async {
    final iconPath = _paths.resolveBundledAsset(_trayIconAsset);
    final iconFrames = _iconFactory.buildFramesFromImagePath(iconPath);
    final List<Uint8List> lightFrames = iconFrames ?? [_iconFactory.buildDefaultIcon(useDarkForeground: false)];
    final List<Uint8List> darkFrames = iconFrames ?? [_iconFactory.buildDefaultIcon(useDarkForeground: true)];
    _lightForegroundFrames = _loadImages(await _iconFactory.writeFramesToTempFiles(lightFrames));
    _darkForegroundFrames = _loadImages(await _iconFactory.writeFramesToTempFiles(darkFrames));
  }

  /// Decodes every frame once up front, so each animation tick only swaps
  /// an already-loaded native image instead of re-reading a file.
  List<Image> _loadImages(List<String> paths) => [
    for (final path in paths)
      Image.fromFile(path) ?? (throw ArgumentError.value(path, 'path', 'Unable to load tray icon frame')),
  ];

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
    _trayIcon?.setTooltip(tooltip);
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

  void _applyMenu() {
    final l10n = _l10n;
    final trayIcon = _trayIcon;
    if (l10n == null || trayIcon == null) return;
    final items = [
      _menuItem(l10n.trayOpenDashboard, _openDashboardController),
      _menuItem(l10n.traySettings, _openSettingsController),
      _menuItem(l10n.trayExit, _exitController),
    ];
    final menu = Menu.create();
    if (menu == null) throw StateError('Unable to create the tray menu');
    menu
      ..addItem(items[0])
      ..addItem(items[1])
      ..addSeparator()
      ..addItem(items[2]);
    trayIcon.setContextMenu(menu);

    // The replaced menu may be the one whose click is being delivered right
    // now (e.g. a locale change triggered from it), so it's released on the
    // next event-loop turn rather than synchronously.
    final previousMenu = _menu;
    final previousItems = _menuItems;
    _menu = menu;
    _menuItems = items;
    Timer.run(() => _disposeMenu(previousMenu, previousItems));
  }

  MenuItem _menuItem(String label, StreamController<void> onClick) {
    final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
    if (item == null) throw StateError('Unable to create tray menu item "$label"');
    item.addListener((event) {
      if (event is MenuItemClickedEvent) onClick.add(null);
    });
    return item;
  }

  void _disposeMenu(Menu? menu, List<MenuItem> items) {
    menu?.dispose();
    for (final item in items) {
      item.dispose();
    }
  }

  void _scheduleNextFrame() {
    _animationTimer?.cancel();
    _animationTimer = Timer(trayTickInterval(_cpuPercent, isPaused: _isPaused), () {
      final frameCount = _lightForegroundFrames.isEmpty
          ? TrayIconFactory.defaultFrameCount
          : _lightForegroundFrames.length;
      _frameIndex = (_frameIndex + 1) % frameCount;
      _setFrame(_frameIndex);
      _scheduleNextFrame();
    });
  }

  void _setFrame(int index) {
    final frames = _useDarkForeground ? _darkForegroundFrames : _lightForegroundFrames;
    if (index < frames.length) _trayIcon?.icon = frames[index];
  }

  void _onTrayIconEvent(TrayIconEvent event) {
    if (event is TrayIconClickedEvent) _openDashboardController.add(null);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h${minutes}m' : '${minutes}m';
  }

  Future<void> dispose() async {
    _animationTimer?.cancel();
    final trayIcon = _trayIcon;
    _trayIcon = null;
    if (trayIcon != null) {
      final listenerId = _trayListenerId;
      if (listenerId != null) trayIcon.removeListener(listenerId);
      trayIcon.dispose();
    }
    _disposeMenu(_menu, _menuItems);
    _menu = null;
    _menuItems = const [];
    for (final image in [..._lightForegroundFrames, ..._darkForegroundFrames]) {
      image.dispose();
    }
    _lightForegroundFrames = const [];
    _darkForegroundFrames = const [];
    await _openDashboardController.close();
    await _openSettingsController.close();
    await _exitController.close();
    await _updateDownloadController.close();
  }
}
