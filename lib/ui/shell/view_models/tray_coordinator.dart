import 'dart:async';
import 'dart:ui' show Locale;

import '../../../data/services/app/tray_service.dart';
import '../../../di/injection.dart';
import '../../../domain/use_cases/cpu_monitor.dart';
import '../../../domain/use_cases/tracking_engine.dart';

/// Starts the system tray and reactively pushes usage/CPU updates into it
/// (tooltip text, animation speed, pause state) — functional spec section
/// 4. A get_it singleton, started once from di/injection.dart's
/// `AppLifecycle.start()` rather than from the widget tree (unlike
/// ui/shell/app_shell.dart, which separately listens to the tray's own
/// request streams — opening the dashboard, exiting — since *that* needs
/// to drive navigation, a UI concern this class has nothing to do with).
///
/// Deliberately minimal for now: it does not yet re-detect light/dark
/// taskbar on system theme changes (tray_service.setTrayForeground exists
/// for that, just not wired to a live OS theme-change signal here) or
/// refresh menu labels when the language setting changes after startup
/// (tray_service.setLocale exists for that too). Follow-up polish once
/// the rest of the app is in place.
class TrayCoordinator {
  TrayCoordinator({TrayService? trayService, TrackingEngine? trackingEngine, CpuMonitor? cpuMonitor})
    : _trayService = trayService ?? getIt<TrayService>(),
      _trackingEngine = trackingEngine ?? getIt<TrackingEngine>(),
      _cpuMonitor = cpuMonitor ?? getIt<CpuMonitor>();

  final TrayService _trayService;
  final TrackingEngine _trackingEngine;
  final CpuMonitor _cpuMonitor;

  final _subscriptions = <StreamSubscription<void>>[];

  Future<void> start({required Locale locale}) async {
    await _trayService.start(locale: locale);

    _subscriptions.add(
      _trackingEngine.snapshots.listen((snapshot) {
        _trayService.updateTooltip(
          isActive: snapshot.isActive,
          isPaused: snapshot.isPaused,
          today: Duration(seconds: snapshot.todayUsage.totalActiveSeconds),
          cpuPercent: _cpuMonitor.current?.usagePercent ?? 0,
        );
        _trayService.setPaused(snapshot.isPaused);
      }),
    );

    _subscriptions.add(_cpuMonitor.samples.listen((sample) => _trayService.setCpuUsagePercent(sample.usagePercent)));
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
