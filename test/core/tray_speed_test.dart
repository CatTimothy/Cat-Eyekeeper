import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/tray_speed.dart';

void main() {
  test('trayTickInterval speeds up with CPU load and slows down when paused', () {
    expect(trayTickInterval(0), const Duration(milliseconds: 500));
    expect(trayTickInterval(5), const Duration(milliseconds: 500));
    expect(trayTickInterval(10), const Duration(milliseconds: 250));
    expect(trayTickInterval(50), const Duration(milliseconds: 50));
    expect(trayTickInterval(100), const Duration(milliseconds: 25));
    expect(trayTickInterval(100, isPaused: true), const Duration(milliseconds: 900));
  });

  test('traySpeedMultiplier is 1x at idle CPU, scaling to 20x at 100%', () {
    expect(traySpeedMultiplier(0), 1);
    expect(traySpeedMultiplier(10), 2);
    expect(traySpeedMultiplier(100), 20);
  });
}
