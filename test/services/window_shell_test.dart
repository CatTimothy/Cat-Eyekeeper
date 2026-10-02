import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/services/app/window_shell.dart';

void main() {
  test('starts on the dashboard, not in reminder fullscreen', () {
    final shell = WindowShell();
    expect(shell.state.screen, AppScreen.dashboard);
    expect(shell.state.isReminderFullscreen, isFalse);
  });

  test('showSettings and the tray entry point both land on the same screen state', () {
    final shell = WindowShell();
    shell.showSettings();
    expect(shell.state.screen, AppScreen.settings);
  });

  test('entering reminder fullscreen preserves the underlying screen', () {
    final shell = WindowShell();
    shell.showSettings();
    shell.enterReminderFullscreen();

    expect(shell.state.isReminderFullscreen, isTrue);
    expect(shell.state.screen, AppScreen.settings); // preserved, not reset to dashboard

    shell.exitReminderFullscreen();
    expect(shell.state.isReminderFullscreen, isFalse);
    expect(shell.state.screen, AppScreen.settings); // still settings after exiting
  });

  test('exitReminderFullscreen defaults to not hiding to tray', () {
    final shell = WindowShell();
    shell.enterReminderFullscreen();
    shell.exitReminderFullscreen();
    expect(shell.state.hideToTrayOnExit, isFalse);
  });

  test('exitReminderFullscreen(hideToTray: true) sets the one-shot flag', () {
    final shell = WindowShell();
    shell.enterReminderFullscreen();
    shell.exitReminderFullscreen(hideToTray: true);
    expect(shell.state.hideToTrayOnExit, isTrue);
  });

  test('a later plain exitReminderFullscreen() clears a previously-set hide flag', () {
    final shell = WindowShell();
    shell.enterReminderFullscreen();
    shell.exitReminderFullscreen(hideToTray: true);
    expect(shell.state.hideToTrayOnExit, isTrue);

    shell.enterReminderFullscreen();
    shell.exitReminderFullscreen();
    expect(shell.state.hideToTrayOnExit, isFalse);
  });

  test('changes stream emits on every transition', () async {
    final shell = WindowShell();
    final emitted = <WindowShellState>[];
    final sub = shell.changes.listen(emitted.add);

    shell.showAbout();
    shell.enterReminderFullscreen();
    shell.exitReminderFullscreen();
    await Future<void>.delayed(Duration.zero);

    expect(emitted.map((s) => s.screen), [AppScreen.about, AppScreen.about, AppScreen.about]);
    expect(emitted.map((s) => s.isReminderFullscreen), [false, true, false]);
    await sub.cancel();
  });
}
