import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// Toggles "launch at login" — a Windows Registry Run key or Linux XDG
/// autostart entry, depending on platform, both handled internally by
/// `launch_at_startup`. [setup] must run once (at app startup) before
/// [apply]/[isEnabled] are called.
class StartupService {
  const StartupService();

  // Deliberately not just "ScreenTime" — this is the Windows Registry Run
  // key value name / Linux autostart entry id, and must not collide with
  // an unrelated app of a similar obvious name.
  static const _appName = 'ScreenTimeFlutter';

  /// `--startup` lets `main.dart` recognize an autostart launch and start
  /// the window hidden/minimized to tray.
  void setup() {
    launchAtStartup.setup(appName: _appName, appPath: Platform.resolvedExecutable, args: const ['--startup']);
  }

  Future<bool> apply(bool enabled) => enabled ? launchAtStartup.enable() : launchAtStartup.disable();

  Future<bool> isEnabled() => launchAtStartup.isEnabled();
}
