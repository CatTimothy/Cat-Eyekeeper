import 'dart:io';

import '../../../../domain/models/foreground_app.dart';
import '../foreground_reader.dart';
import '../fullscreen_checker.dart';
import 'x11_bindings.dart';
import 'x11_fullscreen_checker.dart';

/// Reads the focused window via the EWMH `_NET_ACTIVE_WINDOW` root-window
/// property, then `_NET_WM_PID`/`_NET_WM_NAME` on that window. Requires an
/// EWMH-compliant window manager (all common ones are) and an X11 (or
/// XWayland) session — see wayland_support.dart.
class X11ForegroundReader implements ForegroundReader {
  X11ForegroundReader({FullscreenChecker? fullscreenChecker})
    : _fullscreenChecker = fullscreenChecker ?? X11FullscreenChecker();

  final FullscreenChecker _fullscreenChecker;

  int? _netActiveWindowAtom;
  int? _netWmPidAtom;
  int? _netWmNameAtom;
  int? _utf8StringAtom;

  @override
  ForegroundApp? current() {
    final x11 = X11.instance;
    final root = x11.rootWindow();
    if (root == null) return null;

    _netActiveWindowAtom ??= x11.internAtom('_NET_ACTIVE_WINDOW');
    final activeWindowAtom = _netActiveWindowAtom;
    if (activeWindowAtom == null) return null;

    final activeWindow = x11.getPropertyAsWindow(root, activeWindowAtom);
    if (activeWindow == null || activeWindow == 0) return null;

    _netWmPidAtom ??= x11.internAtom('_NET_WM_PID');
    final pidAtom = _netWmPidAtom;
    final pid = pidAtom != null ? x11.getPropertyAsCardinal(activeWindow, pidAtom) : null;
    if (pid == null) return null;

    _netWmNameAtom ??= x11.internAtom('_NET_WM_NAME');
    _utf8StringAtom ??= x11.internAtom('UTF8_STRING');
    final nameAtom = _netWmNameAtom;
    final utf8Atom = _utf8StringAtom;
    final windowTitle = (nameAtom != null && utf8Atom != null)
        ? x11.getPropertyAsUtf8String(activeWindow, nameAtom, utf8Atom) ?? ''
        : '';

    final executablePath = _resolveExecutablePath(pid);
    final processName = executablePath.isNotEmpty
        ? executablePath.split('/').last
        : (_resolveProcessCommName(pid) ?? 'unknown');

    return ForegroundApp(
      processId: pid,
      // The application identity, not the window title (which changes
      // per document/tab/site) — see win_foreground_reader.dart's
      // _friendlyName doc for why. X11 has no equivalent of Windows'
      // FileDescription version resource, so the executable/command name
      // is the best available stable identity here.
      name: processName,
      processName: processName,
      executablePath: executablePath,
      windowTitle: windowTitle,
      isFullScreen: _fullscreenChecker.isFullScreen(activeWindow),
    );
  }

  /// `/proc/<pid>/exe` is a symlink to the executable's real path —
  /// simpler and more reliable than parsing `/proc/<pid>/maps`.
  String _resolveExecutablePath(int pid) {
    try {
      return Link('/proc/$pid/exe').targetSync();
    } on Object {
      return '';
    }
  }

  /// Fallback when `/proc/<pid>/exe` can't be read (e.g. a process we
  /// don't have permission to inspect): the kernel-reported command name.
  String? _resolveProcessCommName(int pid) {
    try {
      return File('/proc/$pid/comm').readAsStringSync().trim();
    } on Object {
      return null;
    }
  }
}
