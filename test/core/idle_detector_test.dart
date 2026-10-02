import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/idle_detector.dart';

import '../platform/fakes/fake_idle_reader.dart';

void main() {
  test('idleTime is the minimum across every reader (any activity resets idle)', () {
    final hid = FakeIdleReader(initial: const Duration(seconds: 120));
    final gamepad = FakeIdleReader(initial: const Duration(seconds: 5));
    final detector = IdleDetector([hid, gamepad]);

    expect(detector.idleTime(), const Duration(seconds: 5));
  });

  test('isActive is true when at least one reader is below the threshold', () {
    final hid = FakeIdleReader(initial: const Duration(seconds: 120));
    final gamepad = FakeIdleReader(initial: const Duration(seconds: 5));
    final detector = IdleDetector([hid, gamepad]);

    expect(detector.isActive(60), isTrue);
  });

  test('isActive is false only when every reader is past the threshold', () {
    final hid = FakeIdleReader(initial: const Duration(seconds: 120));
    final gamepad = FakeIdleReader(initial: const Duration(seconds: 90));
    final detector = IdleDetector([hid, gamepad]);

    expect(detector.isActive(60), isFalse);
  });
}
