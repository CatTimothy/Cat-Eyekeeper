import '../fullscreen_checker.dart';
import 'x11_bindings.dart';

/// A window counts as fullscreen if its bounds match the X root window's
/// bounds. This compares against the whole X screen rather than the
/// specific monitor the window is on — a reasonable approximation for
/// single-monitor setups. True per-monitor detection would need the
/// RandR extension, which this app doesn't bind.
class X11FullscreenChecker implements FullscreenChecker {
  @override
  bool isFullScreen(int windowHandle) {
    final x11 = X11.instance;
    final windowGeometry = x11.getGeometry(windowHandle);
    if (windowGeometry == null) return false;

    final root = x11.rootWindow();
    if (root == null) return false;
    final rootGeometry = x11.getGeometry(root);
    if (rootGeometry == null) return false;

    return windowGeometry.width == rootGeometry.width && windowGeometry.height == rootGeometry.height;
  }
}
