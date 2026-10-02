import 'package:cat_eyekeeper/data/services/platform/idle_reader.dart';

/// A settable idle-time signal for tests, standing in for keyboard/mouse
/// or gamepad readers without touching any real OS API.
class FakeIdleReader implements IdleReader {
  FakeIdleReader({Duration initial = Duration.zero}) : idleDuration = initial;

  Duration idleDuration;

  @override
  Duration idleTime() => idleDuration;
}
