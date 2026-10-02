/// Reads how long it's been since the last keyboard/mouse input. See
/// windows/win_idle_reader.dart and linux/x11_idle_reader.dart.
abstract class IdleReader {
  Duration idleTime();
}
