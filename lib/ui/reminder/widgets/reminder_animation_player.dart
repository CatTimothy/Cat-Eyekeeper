import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../data/repositories/app_paths.dart';
import '../../../di/injection.dart';

const _startVideoAsset = 'assets/bundled_packs/reminder_animation/star_cat/start_video.webm';
const _continuedVideoAsset = 'assets/bundled_packs/reminder_animation/star_cat/continued_video.webm';

/// 作为背景填满整个提醒界面：播放内置的默认提醒动画（一段开场视频接
/// 一段循环视频），让其后方模糊的桌面背景——见
/// ui/reminder/reminder_overlay.dart——透过视频的透明区域显示出来。
/// video_player 由 fvp 的 mdk 解码器（在 main.dart 中注册一次）而非
/// 标准平台后端提供支持，因为只有 mdk 能把源视频自身的 alpha 通道
/// （VP8/VP9/HEVC）合成传递给 Flutter——正是这一点让视频透明区域能够
/// 透出模糊背景。
class ReminderAnimationPlayer extends StatefulWidget {
  const ReminderAnimationPlayer({super.key});

  @override
  State<ReminderAnimationPlayer> createState() => _ReminderAnimationPlayerState();
}

class _ReminderAnimationPlayerState extends State<ReminderAnimationPlayer> {
  VideoPlayerController? _startController;
  VideoPlayerController? _continuedController;
  VoidCallback? _completionListener;
  bool _showContinued = false;

  @override
  void initState() {
    super.initState();
    _startVideoPlayback();
  }

  @override
  void dispose() {
    _tearDown();
    super.dispose();
  }

  void _startVideoPlayback() {
    final paths = getIt<AppPaths>();
    final startController = VideoPlayerController.file(File(paths.resolveBundledAsset(_startVideoAsset)));
    final continuedController = VideoPlayerController.file(File(paths.resolveBundledAsset(_continuedVideoAsset)));
    _startController = startController;
    _continuedController = continuedController;

    // 一开始就同时初始化两者，这样等起始视频播放完毕时，后续视频
    // 早已缓冲就绪——切换到一个已加载好的控制器是瞬时的，避免了
    // 播放完成后才冷启动 `initialize()` 会造成的加载/解码卡顿。
    // 每个控制器一旦*自己*就绪就立即开始播放，而不等待另一个
    // （后续视频在这里绝不会自动播放——只有在下方起始视频播放完成后
    // 才会播放）。
    continuedController.initialize().then((_) {
      if (!mounted || _continuedController != continuedController) return;
      continuedController.setLooping(true);
      setState(() {});
    });
    startController.initialize().then((_) {
      if (!mounted || _startController != startController) return;
      startController.setLooping(false);

      void listener() {
        final value = startController.value;
        if (!value.isInitialized || value.isPlaying) return;
        if (value.position < value.duration) return;
        if (!mounted || _continuedController != continuedController) return;
        startController.removeListener(listener);
        _completionListener = null;
        continuedController.play();
        setState(() => _showContinued = true);
      }

      _completionListener = listener;
      startController.addListener(listener);
      startController.play();
      setState(() {});
    });
  }

  void _tearDown() {
    final start = _startController;
    final listener = _completionListener;
    if (start != null && listener != null) start.removeListener(listener);
    _completionListener = null;
    _startController?.dispose();
    _continuedController?.dispose();
    _startController = null;
    _continuedController = null;
  }

  @override
  Widget build(BuildContext context) {
    final startController = _startController;
    final continuedController = _continuedController;
    final startReady = startController?.value.isInitialized ?? false;
    final continuedReady = continuedController?.value.isInitialized ?? false;

    if (!startReady && !continuedReady) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (startReady) Opacity(opacity: _showContinued ? 0 : 1, child: _CoverVideo(controller: startController!)),
        if (continuedReady)
          Opacity(opacity: _showContinued ? 1 : 0, child: _CoverVideo(controller: continuedController!)),
      ],
    );
  }
}

/// `VideoPlayer`没有内置的 `fit` 参数（不像 media_kit 旧版的 `Video`
/// widget）——将控制器的原生画面缩放以铺满其边界，效果等同于
/// `BoxFit.cover`。
class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(controller)),
    );
  }
}
