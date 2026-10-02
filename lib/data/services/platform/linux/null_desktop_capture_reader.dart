import '../desktop_capture_reader.dart';

/// Full-desktop screenshot capture and monitor enumeration (X11/Wayland)
/// is a much larger, unverified undertaking than the rest of this app's
/// Linux support — always returns empty lists so the reminder overlay
/// falls back to single-window/flat-background behavior instead of
/// guessing wrong (same precedent as platform/linux/null_app_icon_reader.dart).
class NullDesktopCaptureReader implements DesktopCaptureReader {
  const NullDesktopCaptureReader();

  @override
  List<MonitorBounds> listMonitors() => const [];

  @override
  List<MonitorCapture> captureAllMonitors() => const [];
}
