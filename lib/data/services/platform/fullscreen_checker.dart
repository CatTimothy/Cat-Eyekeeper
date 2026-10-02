/// Checks whether a window covers its monitor. Used by
/// ForegroundReader implementations to populate `ForegroundApp.isFullScreen`
/// (feeds core/reminder_guard.dart's suppression rules).
abstract class FullscreenChecker {
  /// [windowHandle] is an opaque, platform-specific window identifier (an
  /// HWND on Windows, an X11 Window id on Linux).
  bool isFullScreen(int windowHandle);
}
