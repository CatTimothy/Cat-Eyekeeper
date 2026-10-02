import 'package:cat_eyekeeper/data/services/platform/desktop_capture_reader.dart';

/// A settable monitor list/capture set for tests, standing in for a real
/// OS screenshot without touching any Win32 API.
class FakeDesktopCaptureReader implements DesktopCaptureReader {
  FakeDesktopCaptureReader({List<MonitorCapture> captures = const []}) : captures = captures;

  List<MonitorCapture> captures;

  @override
  List<MonitorBounds> listMonitors() => [for (final capture in captures) capture.bounds];

  @override
  List<MonitorCapture> captureAllMonitors() => captures;
}
