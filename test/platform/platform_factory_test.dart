import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/services/platform/platform_factory.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_app_icon_reader.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_cpu_reader.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_foreground_reader.dart';

void main() {
  // GamepadReader touches a platform channel on construction, which
  // requires the Flutter test binding to be initialized first.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('forCurrentPlatform assembles the Windows readers on Windows', () {
    final services = PlatformServices.forCurrentPlatform();

    expect(services.hidReader, isNotNull);
    expect(services.gamepadReader, isNotNull);
    if (Platform.isWindows) {
      expect(services.foregroundReader, isA<WinForegroundReader>());
      expect(services.cpuReader, isA<WinCpuReader>());
      expect(services.appIconReader, isA<WinAppIconReader>());
    }
  });
}
