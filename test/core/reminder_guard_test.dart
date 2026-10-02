import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/reminder_guard.dart';
import 'package:cat_eyekeeper/domain/models/foreground_app.dart';
import 'package:cat_eyekeeper/domain/models/reminder_suppression_reason.dart';

ForegroundApp _app({
  String processName = '',
  String windowTitle = '',
  bool isFullScreen = false,
  String executablePath = '',
}) => ForegroundApp(
  processId: 1,
  name: processName,
  processName: processName,
  executablePath: executablePath,
  windowTitle: windowTitle,
  isFullScreen: isFullScreen,
);

void main() {
  test('a null app is never suppressed', () {
    expect(suppressReminder(null), isNull);
  });

  test('fullscreen presentation software suppresses as presenting', () {
    final app = _app(processName: 'powerpnt', isFullScreen: true);
    expect(suppressReminder(app), ReminderSuppressionReason.presenting);
  });

  test('a non-fullscreen presentation window with a presenter-view title still suppresses', () {
    final app = _app(processName: 'powerpnt', windowTitle: 'Presenter View');
    expect(suppressReminder(app), ReminderSuppressionReason.presenting);
  });

  test('a non-fullscreen media player is never suppressed', () {
    expect(suppressReminder(_app(processName: 'vlc')), isNull);
  });

  test('a fullscreen known media player suppresses as fullscreen video', () {
    final app = _app(processName: 'vlc', isFullScreen: true);
    expect(suppressReminder(app), ReminderSuppressionReason.fullscreenVideo);
  });

  test('a fullscreen browser with a video-site title suppresses', () {
    final app = _app(processName: 'chrome', isFullScreen: true, windowTitle: 'Cats - YouTube');
    expect(suppressReminder(app), ReminderSuppressionReason.fullscreenVideo);
  });

  test('a fullscreen browser without a video-site title does not suppress', () {
    final app = _app(processName: 'chrome', isFullScreen: true, windowTitle: 'Inbox - Gmail');
    expect(suppressReminder(app), isNull);
  });

  test('isMediaPlaybackApp recognizes known players regardless of fullscreen state', () {
    expect(isMediaPlaybackApp(_app(processName: 'mpv')), isTrue);
    expect(isMediaPlaybackApp(_app(processName: 'notepad')), isFalse);
  });
}
