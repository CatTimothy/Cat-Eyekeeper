import 'dart:async';

import '../../../data/services/app/desktop_backdrop_service.dart';
import '../../../data/services/platform/media_key_sender.dart';
import '../../../data/services/platform/platform_factory.dart';
import '../../../di/injection.dart';
import '../../../domain/models/foreground_app.dart';
import '../../../domain/use_cases/reminder_guard.dart';
import '../../../domain/use_cases/reminder_scheduler.dart';
import '../../../domain/use_cases/tracking_engine.dart';
import '../../core/base_view_model.dart';

/// 负责全屏提醒的倒计时定时器以及模糊背景截图的采集——画面级作用域
/// （get_it `registerFactory`，每次触发提醒都是新的一个实例，在
/// ui/reminder/reminder_overlay.dart 挂载时构造、卸载时释放）。刻意
/// 不负责多显示器的 DPI/布局计算（显示器边界、devicePixelRatio、
/// 各显示器的 Positioned 矩形)——那部分留在 View 中，因为它需要
/// `BuildContext` 且必须在每次 build 时重新读取；具体原因见
/// reminder_overlay.dart 自身的注释（这是一个来之不易的多显示器显示
/// 缺陷修复方案，不要想着在这里"清理"它）。
class ReminderViewModel extends BaseViewModel {
  ReminderViewModel({
    TrackingEngine? trackingEngine,
    ReminderScheduler? reminderScheduler,
    DesktopBackdropService? desktopBackdropService,
    MediaKeySender? mediaKeySender,
  }) : _trackingEngine = trackingEngine ?? getIt<TrackingEngine>(),
       _reminderScheduler = reminderScheduler ?? getIt<ReminderScheduler>(),
       _desktopBackdropService = desktopBackdropService ?? getIt<DesktopBackdropService>(),
       _mediaKeySender = mediaKeySender ?? getIt<PlatformServices>().mediaKeySender;

  final TrackingEngine _trackingEngine;
  final ReminderScheduler _reminderScheduler;
  final DesktopBackdropService _desktopBackdropService;
  final MediaKeySender _mediaKeySender;

  Timer? _timer;

  Duration _remaining = Duration.zero;
  Duration get remaining => _remaining;

  List<MonitorBackdrop> _backdrops = const [];
  List<MonitorBackdrop> get backdrops => _backdrops;

  /// 启动倒计时，并触发（尽力而为的）模糊背景截图采集。[currentApp]
  /// 是提醒触发时处于焦点的应用——如果它看起来像是一个媒体播放器，
  /// 会先自动暂停它（功能规格第 3 节）。
  void start({required int breakDurationMinutes, required double overlayBlurStrength, ForegroundApp? currentApp}) {
    final minutes = breakDurationMinutes < 1 ? 1 : breakDurationMinutes;
    _remaining = Duration(minutes: minutes);

    if (currentApp != null && isMediaPlaybackApp(currentApp)) {
      _mediaKeySender.sendPlayPause();
    }

    // 尽力而为：在提醒一触发就立即截图，此时窗口未必已经完成进入
    // 全屏（见 ui/shell/app_shell.dart 的 `_enterReminderFullscreen`）——
    // 如果本应用自己的窗口恰好在那一刻仍然可见，它可能会出现在截图中。
    // 与 platform/app_icon_reader.dart 在不支持的平台上返回 null 属于
    // 同一等级的尽力而为。
    _desktopBackdropService.captureBlurredMonitors(blurStrength: overlayBlurStrength).then((backdrops) {
      _backdrops = backdrops;
      safeNotifyListeners();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        finish('completed');
        return;
      }
      _remaining = next;
      safeNotifyListeners();
    });

    safeNotifyListeners();
  }

  /// 记录结果并停止倒计时。它*本身不会*退出全屏或隐藏到托盘——那部分
  /// 仍由 View 通过 `getIt<WindowShell>()` 完成，因为窗口生命周期不属于
  /// 这个 ViewModel 关心的范围。
  void finish(String action) {
    _timer?.cancel();
    _trackingEngine.resetContinuous(action);
    _reminderScheduler.markReminderClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
