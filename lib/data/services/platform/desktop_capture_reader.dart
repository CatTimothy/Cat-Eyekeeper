import 'dart:typed_data';

/// One monitor's bounds, in virtual-desktop pixel coordinates — which can
/// be negative, or non-zero at the origin, for a monitor positioned left
/// of/above the Windows-designated primary monitor (whose top-left is
/// always exactly (0, 0)).
class MonitorBounds {
  const MonitorBounds({required this.x, required this.y, required this.width, required this.height});

  final int x;
  final int y;
  final int width;
  final int height;
}

/// One monitor's own screenshot, captured separately from every other
/// monitor — as opposed to a single image spanning the whole virtual
/// desktop — so each monitor's reminder-overlay backdrop (see
/// ui/reminder/reminder_overlay.dart) reflects exactly what's behind it.
class MonitorCapture {
  const MonitorCapture({required this.bounds, required this.pngBytes});

  final MonitorBounds bounds;
  final Uint8List pngBytes;
}

/// Captures the real desktop (every window, not just this app's) — used
/// by services/desktop_backdrop_service.dart to build the reminder
/// overlay's blurred backdrop, and by ui/shell/app_shell.dart to
/// size/position the reminder window so it locks every monitor, not just
/// the one it started on. See windows/win_desktop_capture_reader.dart —
/// Linux has no implementation yet (same precedent as
/// platform/app_icon_reader.dart), so callers fall back to
/// single-monitor/flat-background behavior wherever these return an
/// empty list.
abstract class DesktopCaptureReader {
  /// Every connected monitor's bounds — cheap (no pixel capture), used
  /// purely for window positioning. Empty if unsupported or the
  /// underlying OS call fails.
  List<MonitorBounds> listMonitors();

  /// Every connected monitor's own screenshot. May return fewer entries
  /// than [listMonitors] if a specific monitor's capture fails; empty if
  /// unsupported or nothing could be captured.
  List<MonitorCapture> captureAllMonitors();
}
