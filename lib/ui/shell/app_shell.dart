import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/services/app/theme_service.dart';
import '../../data/services/app/tray_service.dart';
import '../../data/services/app/window_shell.dart';
import '../../data/services/platform/platform_factory.dart';
import '../../di/injection.dart';
import '../../domain/use_cases/reminder_scheduler.dart';
import '../../l10n/app_localizations.dart';
import '../core/responsive.dart';
import '../core/view_models/dashboard_status_visibility.dart';
import '../core/view_models/settings_view_model.dart';
import '../core/view_models/update_check_view_model.dart';
import '../shell/view_models/tray_coordinator.dart';
import '../../theme/glass_theme.dart';
import '../about/about_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../reminder/reminder_overlay.dart';
import '../settings/settings_screen.dart';
import 'title_bar.dart';

/// The app's single top-level window. Screen switching
/// (dashboard/settings/about) and the full-screen reminder mode are both
/// driven by [WindowShellState] — this is deliberately the *only* widget
/// that calls `window_manager` (see functional spec architecture notes)
/// for *live* changes; main.dart separately sets the window's initial
/// transparency at cold start, since that first-frame case needs to be
/// handled before this widget's `initState` has even run once.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  final WindowShell _windowShell = getIt<WindowShell>();
  final DashboardStatusVisibility _statusVisibility = getIt<DashboardStatusVisibility>();
  final SettingsViewModel _settingsViewModel = getIt<SettingsViewModel>();
  final UpdateCheckViewModel _updateCheck = getIt<UpdateCheckViewModel>();
  final TrayService _trayService = getIt<TrayService>();

  late WindowShellState _windowState = _windowShell.state;
  StreamSubscription<WindowShellState>? _windowShellSub;
  StreamSubscription<void>? _reminderDueSub;
  final List<StreamSubscription<void>> _traySubscriptions = [];

  /// The window's normal bounds, captured just before a reminder spans it
  /// across every monitor (see [_enterReminderFullscreen]) — restored
  /// verbatim on exit, since (unlike `setFullScreen`) `setBounds` doesn't
  /// have an OS-remembered "previous size" to fall back to. Null when the
  /// reminder used plain single-monitor `setFullScreen` instead (no
  /// monitor bounds available).
  Rect? _boundsBeforeReminder;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    _windowShellSub = _windowShell.changes.listen(_onWindowShellStateChanged);
    _reminderDueSub = getIt<ReminderScheduler>().reminderDue.listen((_) => _windowShell.enterReminderFullscreen());
    _statusVisibility.addListener(_onRebuildNeeded);
    _settingsViewModel.addListener(_onSettingsChanged);
    _updateCheck.addListener(_onRebuildNeeded);

    // The tray is already fully started by the time this widget mounts
    // (main.dart awaits TrayCoordinator.start() before runApp) — this just
    // wires its *request* streams (open dashboard, exit, ...) to actual
    // navigation/window actions, a UI concern TrayCoordinator itself has
    // nothing to do with.
    _wireTray();

    // Handles live theme switches (Settings -> Save); main.dart separately
    // picks a matching initial value at cold start, before this widget
    // exists.
    _applyWindowTransparency();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _windowShellSub?.cancel();
    _reminderDueSub?.cancel();
    for (final sub in _traySubscriptions) {
      sub.cancel();
    }
    _statusVisibility.removeListener(_onRebuildNeeded);
    _settingsViewModel.removeListener(_onSettingsChanged);
    _updateCheck.removeListener(_onRebuildNeeded);
    super.dispose();
  }

  void _onRebuildNeeded() {
    if (mounted) setState(() {});
  }

  void _onSettingsChanged() => _applyWindowTransparency();

  // The only place that decides whether the native window is translucent
  // — every theme except low-opacity custom renders as a fully opaque
  // window. This is plain OS-level compositing (the translucent native
  // window lets the real desktop show through, alpha-blended against a
  // translucent scaffoldBackgroundColor), not a Flutter blur.
  void _applyWindowTransparency() {
    final settings = _settingsViewModel.current;
    final requiresTransparent = getIt<ThemeService>().requiresTransparentWindow(settings.themeMode, settings.customThemeColors);
    windowManager.setBackgroundColor(requiresTransparent ? Colors.transparent : Colors.black);
  }

  void _onWindowShellStateChanged(WindowShellState next) {
    final wasFullscreen = _windowState.isReminderFullscreen;
    setState(() => _windowState = next);
    if (wasFullscreen == next.isReminderFullscreen) return;
    if (next.isReminderFullscreen) {
      _enterReminderFullscreen();
    } else {
      // Only hide once the fullscreen-exit sequence (bounds restore,
      // skip-taskbar/always-on-top/resizable flags) has actually
      // finished — hiding mid-sequence would otherwise leave those OS
      // window flags applied to a hidden window, which then shows back
      // up in the wrong state the next time it's opened from the tray.
      _exitReminderFullscreen().then((_) {
        if (next.hideToTrayOnExit) windowManager.hide();
      });
    }
  }

  // main.dart calls setPreventClose(true), so the native close is already
  // blocked and this fires instead of the window actually closing — hide
  // to the tray. The tray's Exit item is the only path that truly quits.
  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  Future<void> _showAndFocus() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    await getIt<AppLifecycle>().dispose();
    await getIt<TrayCoordinator>().dispose();
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  Future<void> _openLatestDownload() async {
    final result = _updateCheck.result;
    if (result == null) return;
    await launchUrl(Uri.parse(result.latest.downloadUrl));
  }

  void _wireTray() {
    _traySubscriptions.addAll([
      _trayService.openDashboardRequested.listen((_) async {
        _windowShell.showDashboard();
        await _showAndFocus();
      }),
      _trayService.openSettingsRequested.listen((_) async {
        _windowShell.showSettings();
        await _showAndFocus();
      }),
      _trayService.exitRequested.listen((_) => _exitApp()),
      _trayService.updateDownloadRequested.listen((_) => _openLatestDownload()),
    ]);
  }

  Future<void> _enterReminderFullscreen() async {
    await windowManager.setResizable(false);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setAlwaysOnTop(true);

    // Locks every monitor, not just the one the window happens to be on:
    // `setFullScreen` is inherently single-monitor (the OS ties it to
    // whichever monitor contains the window), so when real monitor
    // bounds are available (Windows), span the window across the union
    // of all of them via plain setBounds instead. Falls back to ordinary
    // single-monitor setFullScreen when they're not (Linux).
    //
    // Read fresh every time rather than cached anywhere: monitor bounds
    // aren't static for the life of the app — an exclusive-fullscreen
    // game on a secondary monitor can change that monitor's actual
    // resolution while it runs, and a stale bounds here desyncs the
    // spanned window (and reminder_overlay.dart's per-monitor layout,
    // which reads the same platform call independently) from the real
    // screen geometry — the countdown/close button and animation land in
    // the wrong place. A plain method call is inherently fresh, unlike
    // the old Riverpod provider this replaced, which needed an explicit
    // `ref.invalidate` immediately before every read to avoid serving a
    // cached value.
    final monitors = getIt<PlatformServices>().desktopCaptureReader.listMonitors();
    if (monitors.isEmpty) {
      await windowManager.setFullScreen(true);
    } else {
      _boundsBeforeReminder = await windowManager.getBounds();
      // MonitorBounds are raw physical pixels; window_manager's setBounds
      // takes logical pixels and multiplies by the window's current
      // devicePixelRatio internally to get back to physical ones for
      // SetWindowPos — dividing by that same ratio here cancels that back
      // out, so the requested physical envelope matches the real union of
      // monitors regardless of what that ratio happens to be (matters once
      // any monitor runs above 100% scale, see reminder_overlay.dart).
      //
      // Read as late as possible — immediately before the call it's used
      // in, with no `await` in between — rather than earlier in this
      // method: window_manager's own setBounds() re-reads
      // window.devicePixelRatio itself, fresh, the instant it's called
      // (see window_manager's setBounds()/getDevicePixelRatio()). A DPI
      // change during any of the earlier awaited calls above (e.g. a
      // secondary-monitor game exiting exclusive fullscreen mid-sequence)
      // would otherwise divide by a stale ratio here while setBounds
      // multiplies back out by the new one, so the two no longer cancel
      // and the physical envelope it requests drifts off the real
      // monitor union.
      if (!mounted) return;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final minX = monitors.map((m) => m.x).reduce(math.min);
      final minY = monitors.map((m) => m.y).reduce(math.min);
      final maxRight = monitors.map((m) => m.x + m.width).reduce(math.max);
      final maxBottom = monitors.map((m) => m.y + m.height).reduce(math.max);
      await windowManager.setBounds(
        Rect.fromLTWH(minX / dpr, minY / dpr, (maxRight - minX) / dpr, (maxBottom - minY) / dpr),
      );
    }
    await _showAndFocus();
  }

  Future<void> _exitReminderFullscreen() async {
    final previousBounds = _boundsBeforeReminder;
    if (previousBounds != null) {
      _boundsBeforeReminder = null;
      await windowManager.setBounds(previousBounds);
    } else {
      await windowManager.setFullScreen(false);
    }
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setResizable(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final windowState = _windowState;
    final theme = Theme.of(context);

    // Only wired up on the dashboard at compact/mobile width — tapping
    // the title bar there toggles the stat cards to trade them for more
    // chart/app-list room (ui/dashboard/dashboard_screen.dart reads the
    // same shared toggle, ignoring it at desktop width).
    final dashboardCollapsible = windowState.screen == AppScreen.dashboard && isCompactWidth(context);
    final statusVisible = _statusVisibility.visible;

    // A translucent scaffoldBackgroundColor (custom mode with opacity < 1)
    // alpha-blends against the real desktop showing through the
    // transparent native window (see _applyWindowTransparency above) —
    // this is plain OS-level compositing, not a Flutter blur, so it works
    // even though true blur-through isn't possible here. `glass` instead
    // paints its own gradient (theme/glass_theme.dart) so that
    // GlassSurface panels elsewhere have real Flutter-drawn detail behind
    // them to blur — blurring a flat color would be a visual no-op.
    final glass = theme.extension<GlassTheme>();
    final content = Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          if (!windowState.isReminderFullscreen)
            TitleBar(
              title: _titleFor(l10n, windowState.screen),
              onTap: dashboardCollapsible ? () => _statusVisibility.toggle() : null,
              tappedIndicator: dashboardCollapsible
                  ? Icon(statusVisible ? Icons.expand_less : Icons.expand_more, size: 16)
                  : null,
            ),
          Expanded(child: _buildBody(windowState)),
        ],
      ),
    );

    return glass == null
        ? ColoredBox(color: theme.scaffoldBackgroundColor, child: content)
        : DecoratedBox(decoration: BoxDecoration(gradient: glass.backgroundGradient), child: content);
  }

  String _titleFor(AppLocalizations l10n, AppScreen screen) {
    switch (screen) {
      case AppScreen.dashboard:
        return l10n.appTitle;
      case AppScreen.settings:
        return l10n.settingsScreenTitle;
      case AppScreen.about:
        return l10n.aboutScreenTitle;
    }
  }

  Widget _buildBody(WindowShellState windowState) {
    if (windowState.isReminderFullscreen) return const ReminderOverlay();
    switch (windowState.screen) {
      case AppScreen.dashboard:
        return const DashboardScreen();
      case AppScreen.settings:
        return const SettingsScreen();
      case AppScreen.about:
        return const AboutScreen();
    }
  }
}
