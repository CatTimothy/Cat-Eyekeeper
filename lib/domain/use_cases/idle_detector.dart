import '../../data/services/platform/idle_reader.dart';

/// Combines every input signal (keyboard/mouse, gamepad, ...) into one
/// idle judgement: active if *any* signal has seen activity recently.
/// Functional spec section 1 / requirement 4. Adding a new signal (e.g.
/// touch) is just adding another [IdleReader] to the list — this class
/// doesn't know or care what kind of input each reader represents.
class IdleDetector {
  IdleDetector(this._readers) : assert(_readers.isNotEmpty, 'IdleDetector needs at least one IdleReader');

  final List<IdleReader> _readers;

  Duration idleTime() => _readers.map((r) => r.idleTime()).reduce((a, b) => a < b ? a : b);

  bool isActive(int thresholdSeconds) => idleTime() < Duration(seconds: thresholdSeconds);
}
