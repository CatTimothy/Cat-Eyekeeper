import 'dart:async';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

/// Guards against a second copy of the app running alongside an already
/// running one — without this, launching the app twice (e.g. double-
/// clicking the desktop shortcut while it's already in the tray) would
/// start a second `TrackingEngine` ticking against the same on-disk usage
/// file, a second tray icon, and a second autostart registration all
/// fighting the first.
///
/// Uses a fixed loopback TCP port as a cross-platform mutex — binding a
/// port is exclusive to one process on both Windows and Linux, and
/// (unlike a lock file) the OS releases it automatically if the process
/// dies without a chance to clean up. Whichever process binds first is
/// the "primary" and keeps listening for the lifetime of the app; every
/// later launch fails to bind, pings the primary so it can bring its
/// window to the foreground, and exits immediately without doing any
/// further startup work.
class SingleInstanceService {
  /// [onPinged] runs whenever a later launch pings this process after
  /// failing to claim the port — defaults to bringing the real app window
  /// forward. Overridable so tests can substitute a spy instead of driving
  /// an actual `window_manager` platform channel, which has nothing to
  /// respond on it outside a running app.
  SingleInstanceService({this.port = 47821, Future<void> Function()? onPinged})
    : _onPinged = onPinged ?? _showAppWindow;

  final int port;
  final Future<void> Function() _onPinged;
  ServerSocket? _server;

  static Future<void> _showAppWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Returns true if this process claimed the primary role and should
  /// continue starting normally. Returns false if another instance is
  /// already running — in that case the existing instance has already
  /// been pinged to show itself, and the caller should exit right away.
  Future<bool> claim() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      await _pingPrimary();
      return false;
    }
    _server!.listen((socket) {
      _onPinged();
      socket.destroy();
    });
    return true;
  }

  Future<void> _pingPrimary() async {
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 2));
      await socket.close();
    } on SocketException {
      // The primary isn't accepting connections (e.g. mid-shutdown) —
      // nothing more this launch can do; still exit rather than run a
      // second copy.
    } on TimeoutException {
      // As above.
    }
  }

  Future<void> dispose() async {
    await _server?.close();
    _server = null;
  }
}
