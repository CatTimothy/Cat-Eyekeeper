import 'dart:async';

enum AppScreen { dashboard, settings, about }

class WindowShellState {
  const WindowShellState({required this.screen, required this.isReminderFullscreen, this.hideToTrayOnExit = false});

  final AppScreen screen;
  final bool isReminderFullscreen;

  /// One-shot flag consumed by ui/shell/app_shell.dart's listener: set by
  /// [WindowShell.exitReminderFullscreen]'s `hideToTray` argument (the
  /// reminder overlay's close button) so the window drops straight to the
  /// tray after the fullscreen reminder ends, instead of leaving the
  /// dashboard visible.
  final bool hideToTrayOnExit;

  WindowShellState copyWith({AppScreen? screen, bool? isReminderFullscreen}) => WindowShellState(
    screen: screen ?? this.screen,
    isReminderFullscreen: isReminderFullscreen ?? this.isReminderFullscreen,
  );

  static const initial = WindowShellState(screen: AppScreen.dashboard, isReminderFullscreen: false);
}

/// Tracks which screen is showing (dashboard/settings/about) and whether
/// the window is in the full-screen break-reminder mode. Deliberately has
/// no `window_manager` dependency — `ui/shell/app_shell.dart` is the one
/// place that turns these state changes into actual OS window calls
/// (fullscreen/always-on-top/skip-taskbar), which keeps this class
/// trivially testable without a real window.
///
/// The main-panel settings button and the tray's "Settings" menu item
/// both just call [showSettings] — since it's the same state and the same
/// screen widget reacts to it, there's no way for the two entry points to
/// diverge (functional spec requirement 1).
class WindowShell {
  WindowShell() : _state = WindowShellState.initial;

  final _controller = StreamController<WindowShellState>.broadcast();
  WindowShellState _state;

  WindowShellState get state => _state;
  Stream<WindowShellState> get changes => _controller.stream;

  void showDashboard() => _update(_state.copyWith(screen: AppScreen.dashboard));
  void showSettings() => _update(_state.copyWith(screen: AppScreen.settings));
  void showAbout() => _update(_state.copyWith(screen: AppScreen.about));

  /// Enters the full-screen reminder overlay. The screen underneath is
  /// preserved, so returning to it after [exitReminderFullscreen] resumes
  /// exactly where the user was.
  void enterReminderFullscreen() => _update(_state.copyWith(isReminderFullscreen: true));

  /// [hideToTray]: set when the user explicitly closed the reminder (the
  /// overlay's close button) rather than it running to completion — the
  /// window drops straight to the tray afterwards instead of leaving the
  /// dashboard sitting on screen. See [WindowShellState.hideToTrayOnExit].
  void exitReminderFullscreen({bool hideToTray = false}) =>
      _update(WindowShellState(screen: _state.screen, isReminderFullscreen: false, hideToTrayOnExit: hideToTray));

  void _update(WindowShellState next) {
    _state = next;
    _controller.add(next);
  }

  Future<void> dispose() => _controller.close();
}
