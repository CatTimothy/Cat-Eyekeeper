import '../../../domain/models/foreground_app.dart';

/// Reads the currently focused window/process. See
/// windows/win_foreground_reader.dart and linux/x11_foreground_reader.dart.
abstract class ForegroundReader {
  /// Returns null if no window is focused, the process died mid-query, or
  /// the platform can't report this (e.g. an unsupported Wayland session —
  /// see linux/wayland_support.dart).
  ForegroundApp? current();
}
