import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/services/app/window_shell.dart';
import '../../data/services/platform/desktop_capture_reader.dart' show MonitorBounds;
import '../../data/services/platform/platform_factory.dart';
import '../../di/injection.dart';
import '../../domain/use_cases/reminder_scheduler.dart';
import '../../l10n/app_localizations.dart';
import '../core/view_models/settings_view_model.dart';
import 'view_models/reminder_view_model.dart';
import 'widgets/countdown_card.dart';
import 'widgets/reminder_animation_player.dart';

/// 全屏休息提醒界面。由 ui/shell/app_shell.dart 根据 WindowShell 的
/// `isReminderFullscreen` 标志负责进入/退出。参见功能规格第 3 节。
class ReminderOverlay extends StatefulWidget {
  const ReminderOverlay({super.key});

  @override
  State<ReminderOverlay> createState() => _ReminderOverlayState();
}

class _ReminderOverlayState extends State<ReminderOverlay> {
  // 画面级作用域（registerFactory）——每次触发提醒都是新的一个实例，
  // 因为每次 ui/shell/app_shell.dart 进入提醒全屏时该 widget 本身
  // 都会被重新挂载。
  late final ReminderViewModel _viewModel = getIt<ReminderViewModel>();
  final SettingsViewModel _settingsViewModel = getIt<SettingsViewModel>();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start();
  }

  void _start() {
    final settings = _settingsViewModel.current;
    final currentApp = getIt<ReminderScheduler>().lastRequest?.currentApp;
    _viewModel.start(
      breakDurationMinutes: settings.breakDurationMinutes,
      overlayBlurStrength: settings.overlayBlurStrength,
      currentApp: currentApp,
    );
  }

  void _finish(String action, {bool hideToTray = false}) {
    _viewModel.finish(action);
    getIt<WindowShell>().exitReminderFullscreen(hideToTray: hideToTray);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_viewModel, _settingsViewModel]),
      builder: (context, _) => _buildOverlay(context),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = _settingsViewModel.current;
    final blurSigma = settings.overlayBlurStrength * 34;
    final backdrops = _viewModel.backdrops;

    // 权威的显示器列表——不从 [backdrops] 推导，因为后者可能独立地
    // 因截图失败而缺失（Linux，或尽力而为的 BitBlt 截图未命中），
    // 而窗口早已跨越了这里列出的每一台显示器（见
    // ui/shell/app_shell.dart 的 `_enterReminderFullscreen`），其左上角
    // 位于它们的并集处。缺少自身背景截图的显示器仍会得到纯色兜底
    // 和自己的播放器（见下文），而不是被留空。
    final monitors = getIt<PlatformServices>().desktopCaptureReader.listMonitors();
    // MonitorBounds 是来自 win32 EnumDisplayMonitors 的原始物理像素，
    // 但下面的每个 widget 都工作在 Flutter 逻辑像素下——在这里统一除以
    // 窗口当前的 devicePixelRatio 完成一次换算，而不是在每个调用点各自
    // 换算。即使所有显示器共用同一个缩放系数（只要不是恰好 100%）也
    // 是必须的，若各显示器缩放系数*不同*则更是如此：让窗口跨越它们
    // 可能导致 Windows 在过程中切换单个 Flutter 视图所报告的 DPI
    // （WM_DPICHANGED），所以这个值必须在每次 build 时重新读取，而不能
    // 假定为常量——否则每台显示器的 Positioned 矩形会按错误的缩放系数
    // 计算尺寸，这正是曾经导致动画看起来像一段视频被斜切横跨两块屏幕、
    // 倒计时/关闭按钮跑偏到角落的原因。
    final dpr = MediaQuery.of(context).devicePixelRatio;
    // 一次调用即转换整个显示器矩形（x/y/width/height 一起处理），而不是
    // 让每个字段各自单独做除法——这样未来修改这个方法时就不会不小心
    // 转换了三个字段却漏掉第四个，从而悄悄地为那一个字段重新引入
    // 物理像素/逻辑像素不匹配的问题。
    Rect toLogicalRect(MonitorBounds m) => Rect.fromLTWH(m.x / dpr, m.y / dpr, m.width / dpr, m.height / dpr);

    // 先对原始物理像素值做归约、之后再统一换算一次（而不是先换算每台
    // 显示器再归约）在结果上是等价的——除以同一个正的 dpr 不会改变
    // 哪个值最小——并且省去了逐台显示器的换算。
    final unionMinX = monitors.isEmpty ? 0.0 : monitors.map((m) => m.x).reduce(math.min) / dpr;
    final unionMinY = monitors.isEmpty ? 0.0 : monitors.map((m) => m.y).reduce(math.min) / dpr;
    // Windows 总是把主显示器的左上角放在虚拟桌面坐标的 (0, 0) 处——
    // 应把倒计时/关闭按钮固定锚定在这一台显示器上，而不是并集窗口的
    // 角落，因为一台位于其左侧/上方的副显示器可能会让并集的 (0,0)
    // 完全落在错误的屏幕上。
    final primary = monitors.isEmpty ? null : monitors.firstWhere((m) => m.x == 0 && m.y == 0, orElse: () => monitors.first);
    final primaryRect = primary != null ? toLogicalRect(primary) : null;
    final controlsLeft = primaryRect != null ? primaryRect.left - unionMinX : 0.0;
    final controlsTop = primaryRect != null ? primaryRect.top - unionMinY : 0.0;

    Widget backdropFor(int x, int y) {
      for (final backdrop in backdrops) {
        if (backdrop.bounds.x == x && backdrop.bounds.y == y) {
          return Image.memory(backdrop.blurredPngBytes, fit: BoxFit.cover, gaplessPlayback: true);
        }
      }
      return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    }

    // 在下方每台显示器各自的 Stack 中重复出现，这样无论用户正在看哪块
    // 屏幕都能看到剩余时间，而不仅限于主屏幕。只有倒计时正后方的一小块
    // 区域被模糊处理（对动画做真正的 BackdropFilter 模糊，因为那是真实
    // 的 Flutter 绘制内容）——裁剪成卡片自身的形状，这样模糊效果就不会
    // 蔓延到动画的其余部分。
    Widget countdownOverlay() {
      return Positioned(
        top: 24,
        left: 24,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: CountdownCard(remaining: _viewModel.remaining),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (monitors.isEmpty)
          // 单显示器兜底方案（Linux，或显示器枚举失败）——用一张背景图
          // 和一个播放器填满整个窗口，与本应用最初的单显示器行为一致。
          Stack(
            fit: StackFit.expand,
            children: [backdropFor(0, 0), const ReminderAnimationPlayer(), countdownOverlay()],
          )
        else
          ...monitors.map((monitor) {
            final rect = toLogicalRect(monitor);
            return Positioned(
              left: rect.left - unionMinX,
              top: rect.top - unionMinY,
              width: rect.width,
              height: rect.height,
              // 窗口背后这台显示器的真实截图，经过模糊处理
              // （services/desktop_backdrop_service.dart），使透明的
              // 提醒图片/视频在任何主题下都能正确显示——加上这台显示器
              // 独立播放的动画实例（而不是一段视频被拉伸横跨所有
              // 显示器），这样每块屏幕都能以自己原生的缩放比例显示美术
              // 内容。
              child: Stack(
                fit: StackFit.expand,
                children: [
                  backdropFor(monitor.x, monitor.y),
                  ReminderAnimationPlayer(key: ValueKey('${monitor.x}_${monitor.y}')),
                  countdownOverlay(),
                ],
              ),
            );
          }),
        // 关闭按钮始终只出现在主显示器上（见上方 controlsLeft/Top）——
        // 关闭是单次性动作，不像倒计时那样需要在每块屏幕上重复出现。
        if (settings.allowCloseFullscreenReminder)
          Positioned(
            left: controlsLeft,
            top: controlsTop,
            right: primary == null ? 0 : null,
            bottom: primary == null ? 0 : null,
            width: primaryRect?.width,
            height: primaryRect?.height,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.reminderCloseEarly,
                  onPressed: () => _finish('closed', hideToTray: true),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
