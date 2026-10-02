import '../idle_reader.dart';
import 'x11_bindings.dart';

/// Reads keyboard/mouse idle time via the XScreenSaver extension.
class X11IdleReader implements IdleReader {
  @override
  Duration idleTime() {
    final millis = X11.instance.screenSaverIdleMilliseconds();
    if (millis == null) return Duration.zero;
    return Duration(milliseconds: millis);
  }
}
