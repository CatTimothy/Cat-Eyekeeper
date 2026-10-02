// Runtime smoke tests for the Win32 FFI readers — these actually call into
// user32.dll/kernel32.dll, so they only make sense (and only load) on a
// real Windows host. Assertions stay loose since CI/headless runners may
// have no interactive desktop session (no real foreground window).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_app_icon_reader.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_cpu_reader.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_desktop_capture_reader.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_foreground_reader.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_fullscreen_checker.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_idle_reader.dart';
import 'package:cat_eyekeeper/data/services/platform/windows/win_media_key_sender.dart';

void main() {
  test(
    'WinIdleReader returns a non-negative idle duration without throwing',
    () {
      final idleTime = WinIdleReader().idleTime();
      expect(idleTime, greaterThanOrEqualTo(Duration.zero));
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinCpuReader seeds on the first sample, then returns a valid percentage',
    () {
      final reader = WinCpuReader();
      final first = reader.sampleUsagePercent();
      expect(first, isNull);

      final second = reader.sampleUsagePercent();
      if (second != null) {
        expect(second, inInclusiveRange(0, 100));
      }
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinFullscreenChecker handles an invalid window handle gracefully',
    () {
      expect(WinFullscreenChecker().isFullScreen(0), isFalse);
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinMediaKeySender does not throw when sending play/pause',
    () {
      expect(() => WinMediaKeySender().sendPlayPause(), returnsNormally);
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinForegroundReader does not throw, and any returned app has an appId',
    () {
      final app = WinForegroundReader().current();
      if (app != null) {
        expect(app.appId, isNotEmpty);
      }
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'readFileDescription reads the friendly name off a known system executable',
    () {
      // notepad.exe ships on every Windows install and always has a
      // FileDescription version resource — a stable real-world fixture for
      // exercising the actual FFI path instead of just not-throwing. The
      // string itself is OS-locale-dependent (e.g. "記事本" on zh-Hant
      // Windows), so only assert that something real came back.
      final description = readFileDescription('C:\\Windows\\System32\\notepad.exe');
      expect(description, isNotNull);
      expect(description!.trim(), isNotEmpty);
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'readFileDescription returns null for a nonexistent path instead of throwing',
    () {
      expect(readFileDescription('C:\\this\\path\\does\\not\\exist.exe'), isNull);
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinAppIconReader extracts a valid PNG for a known system executable',
    () {
      // notepad.exe ships on every Windows install and always has an icon
      // resource — a stable real-world fixture for exercising the actual
      // HICON -> DIB -> PNG conversion.
      final bytes = WinAppIconReader().read('C:\\Windows\\System32\\notepad.exe');
      expect(bytes, isNotNull);
      // PNG file signature: 89 50 4E 47 0D 0A 1A 0A.
      expect(bytes!.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinAppIconReader returns null for a nonexistent path instead of throwing',
    () {
      expect(WinAppIconReader().read('C:\\this\\path\\does\\not\\exist.exe'), isNull);
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinDesktopCaptureReader.listMonitors returns at least one non-empty monitor',
    () {
      final monitors = WinDesktopCaptureReader().listMonitors();
      expect(monitors, isNotEmpty);
      for (final monitor in monitors) {
        expect(monitor.width, greaterThan(0));
        expect(monitor.height, greaterThan(0));
      }
      // The Windows-designated primary monitor's top-left is always
      // exactly (0, 0) in virtual-desktop coordinates.
      expect(monitors.any((m) => m.x == 0 && m.y == 0), isTrue);
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );

  test(
    'WinDesktopCaptureReader.captureAllMonitors returns one valid PNG per monitor',
    () {
      final reader = WinDesktopCaptureReader();
      final monitors = reader.listMonitors();
      final captures = reader.captureAllMonitors();
      expect(captures.length, monitors.length);
      for (final capture in captures) {
        // PNG file signature: 89 50 4E 47 0D 0A 1A 0A.
        expect(capture.pngBytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      }
    },
    skip: Platform.isWindows ? false : 'Win32 FFI only runs on Windows',
  );
}
