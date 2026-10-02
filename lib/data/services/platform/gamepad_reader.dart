import 'dart:async';

import 'package:gamepads/gamepads.dart';

import 'idle_reader.dart';

/// Tracks time since the last gamepad button/axis event, across all
/// connected controllers. The `gamepads` package is already cross-platform
/// (Windows/Linux/macOS), so this has no per-OS variant. Implements
/// [IdleReader] so core/idle_detector.dart can treat it as just another
/// activity signal alongside keyboard/mouse (functional spec section 1 /
/// requirement 4).
class GamepadReader implements IdleReader {
  GamepadReader({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _lastActivityAt = _now();
    _subscription = Gamepads.events.listen((_) => _lastActivityAt = _now());
  }

  final DateTime Function() _now;
  late DateTime _lastActivityAt;
  StreamSubscription<GamepadEvent>? _subscription;

  @override
  Duration idleTime() => _now().difference(_lastActivityAt);

  Future<void> dispose() => _subscription?.cancel() ?? Future.value();
}
