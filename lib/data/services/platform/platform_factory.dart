import 'dart:io';

import 'app_icon_reader.dart';
import 'cpu_reader.dart';
import 'desktop_capture_reader.dart';
import 'foreground_reader.dart';
import 'fullscreen_checker.dart';
import 'gamepad_reader.dart';
import 'idle_reader.dart';
import 'linux/mpris_media_key_sender.dart';
import 'linux/null_app_icon_reader.dart';
import 'linux/null_desktop_capture_reader.dart';
import 'linux/proc_cpu_reader.dart';
import 'linux/x11_foreground_reader.dart';
import 'linux/x11_fullscreen_checker.dart';
import 'linux/x11_idle_reader.dart';
import 'media_key_sender.dart';
import 'windows/win_app_icon_reader.dart';
import 'windows/win_cpu_reader.dart';
import 'windows/win_desktop_capture_reader.dart';
import 'windows/win_foreground_reader.dart';
import 'windows/win_fullscreen_checker.dart';
import 'windows/win_idle_reader.dart';
import 'windows/win_media_key_sender.dart';

/// Bundles every platform-specific reader this app needs, chosen once at
/// startup based on the host OS. Deliberately stays a sibling of domain/ —
/// it hands back raw readers, not an assembled [IdleDetector] (that
/// composition happens in di/injection.dart, which is free to depend on
/// both domain/ and platform/). This is the one place that knows which
/// concrete implementation backs each platform/*.dart interface.
class PlatformServices {
  PlatformServices({
    required this.hidReader,
    required this.gamepadReader,
    required this.foregroundReader,
    required this.cpuReader,
    required this.fullscreenChecker,
    required this.mediaKeySender,
    required this.appIconReader,
    required this.desktopCaptureReader,
  });

  factory PlatformServices.forCurrentPlatform() {
    final FullscreenChecker fullscreenChecker;
    final IdleReader hidReader;
    final ForegroundReader foregroundReader;
    final CpuReader cpuReader;
    final MediaKeySender mediaKeySender;
    final AppIconReader appIconReader;
    final DesktopCaptureReader desktopCaptureReader;

    if (Platform.isWindows) {
      fullscreenChecker = WinFullscreenChecker();
      hidReader = WinIdleReader();
      foregroundReader = WinForegroundReader(fullscreenChecker: fullscreenChecker);
      cpuReader = WinCpuReader();
      mediaKeySender = WinMediaKeySender();
      appIconReader = WinAppIconReader();
      desktopCaptureReader = WinDesktopCaptureReader();
    } else if (Platform.isLinux) {
      fullscreenChecker = X11FullscreenChecker();
      hidReader = X11IdleReader();
      foregroundReader = X11ForegroundReader(fullscreenChecker: fullscreenChecker);
      cpuReader = ProcCpuReader();
      mediaKeySender = MprisMediaKeySender();
      appIconReader = const NullAppIconReader();
      desktopCaptureReader = const NullDesktopCaptureReader();
    } else {
      throw UnsupportedError('${Platform.operatingSystem} is not a supported target platform.');
    }

    return PlatformServices(
      hidReader: hidReader,
      gamepadReader: GamepadReader(),
      foregroundReader: foregroundReader,
      cpuReader: cpuReader,
      fullscreenChecker: fullscreenChecker,
      mediaKeySender: mediaKeySender,
      appIconReader: appIconReader,
      desktopCaptureReader: desktopCaptureReader,
    );
  }

  final IdleReader hidReader;
  final GamepadReader gamepadReader;
  final ForegroundReader foregroundReader;
  final CpuReader cpuReader;
  final FullscreenChecker fullscreenChecker;
  final MediaKeySender mediaKeySender;
  final AppIconReader appIconReader;
  final DesktopCaptureReader desktopCaptureReader;
}
