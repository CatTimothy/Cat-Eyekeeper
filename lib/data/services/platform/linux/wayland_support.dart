import 'dart:io';

/// Whether the current session is X11 (or XWayland), where foreground-
/// window tracking and idle detection work via the standard X11 APIs. A
/// native Wayland session (GNOME/KDE without an XWayland fallback for the
/// active app) has no standard API for either, so callers should degrade
/// gracefully rather than assume these readers always succeed.
///
/// See functional spec / known platform gaps: this is a hard limitation
/// of Wayland's security model, not something this app can work around.
bool get isX11SessionAvailable {
  final sessionType = Platform.environment['XDG_SESSION_TYPE']?.toLowerCase();
  if (sessionType == 'x11') return true;
  // No XDG_SESSION_TYPE (older setups) but DISPLAY is set: assume X11.
  if (sessionType == null || sessionType.isEmpty) {
    return (Platform.environment['DISPLAY'] ?? '').isNotEmpty;
  }
  return false;
}
