import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../fullscreen_checker.dart';

/// A window counts as fullscreen if its bounds cover its monitor's bounds
/// within a small pixel tolerance (some apps leave a hairline gap).
class WinFullscreenChecker implements FullscreenChecker {
  static const _tolerancePixels = 8;

  @override
  bool isFullScreen(int windowHandle) {
    final windowRect = calloc<RECT>();
    final monitorInfo = calloc<MONITORINFO>();
    try {
      if (GetWindowRect(windowHandle, windowRect) == 0) return false;

      final monitor = MonitorFromWindow(windowHandle, MONITOR_DEFAULTTONEAREST);
      if (monitor == 0) return false;

      monitorInfo.ref.cbSize = sizeOf<MONITORINFO>();
      if (GetMonitorInfo(monitor, monitorInfo) == 0) return false;

      final monitorRect = monitorInfo.ref.rcMonitor;
      final window = windowRect.ref;
      return (window.left - monitorRect.left).abs() <= _tolerancePixels &&
          (window.top - monitorRect.top).abs() <= _tolerancePixels &&
          (window.right - monitorRect.right).abs() <= _tolerancePixels &&
          (window.bottom - monitorRect.bottom).abs() <= _tolerancePixels;
    } finally {
      calloc.free(windowRect);
      calloc.free(monitorInfo);
    }
  }
}
