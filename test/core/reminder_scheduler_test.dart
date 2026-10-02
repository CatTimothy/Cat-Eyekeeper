import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/reminder_scheduler.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';
import 'package:cat_eyekeeper/domain/models/foreground_app.dart';
import 'package:cat_eyekeeper/domain/models/reminder_request.dart';
import 'package:cat_eyekeeper/domain/models/settings.dart';
import 'package:cat_eyekeeper/domain/models/usage_snapshot.dart';

Settings _settings({bool reminderEnabled = true, int reminderIntervalMinutes = 1}) =>
    Settings.defaults().copyWith(reminderEnabled: reminderEnabled, reminderIntervalMinutes: reminderIntervalMinutes);

UsageSnapshot _snapshot({int continuousActiveSeconds = 0, bool isPaused = false, ForegroundApp? currentApp}) =>
    UsageSnapshot(
      todayUsage: DailyUsage(date: DateTime(2026, 1, 1), continuousActiveSeconds: continuousActiveSeconds),
      currentApp: currentApp,
      isActive: !isPaused,
      isPaused: isPaused,
      idleTime: Duration.zero,
      updatedAt: DateTime(2026, 1, 1),
    );

final _fullscreenVideoApp = ForegroundApp(
  processId: 1,
  name: 'vlc',
  processName: 'vlc',
  executablePath: '',
  windowTitle: '',
  isFullScreen: true,
);

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  test('fires once continuous seconds reach the 1-minute threshold', () async {
    final scheduler = ReminderScheduler(settings: _settings(reminderIntervalMinutes: 1));
    final fired = <ReminderRequest>[];
    scheduler.reminderDue.listen(fired.add);

    scheduler.observe(_snapshot(continuousActiveSeconds: 59));
    await _flushMicrotasks();
    expect(fired, isEmpty);

    scheduler.observe(_snapshot(continuousActiveSeconds: 60));
    await _flushMicrotasks();
    expect(fired, hasLength(1));
    expect(fired.single.thresholdSeconds, 60);
  });

  test('threshold is clamped to at least 1 second', () async {
    final scheduler = ReminderScheduler(settings: _settings(reminderIntervalMinutes: 0));
    final fired = <ReminderRequest>[];
    scheduler.reminderDue.listen(fired.add);

    scheduler.observe(_snapshot(continuousActiveSeconds: 1));
    await _flushMicrotasks();
    expect(fired.single.thresholdSeconds, 1);
  });

  test('does not fire when reminders are disabled', () async {
    final scheduler = ReminderScheduler(settings: _settings(reminderEnabled: false, reminderIntervalMinutes: 1));
    final fired = <ReminderRequest>[];
    scheduler.reminderDue.listen(fired.add);

    scheduler.observe(_snapshot(continuousActiveSeconds: 60));
    await _flushMicrotasks();
    expect(fired, isEmpty);
  });

  test('does not fire while paused', () async {
    final scheduler = ReminderScheduler(settings: _settings(reminderIntervalMinutes: 1));
    final fired = <ReminderRequest>[];
    scheduler.reminderDue.listen(fired.add);

    scheduler.observe(_snapshot(continuousActiveSeconds: 60, isPaused: true));
    await _flushMicrotasks();
    expect(fired, isEmpty);
  });

  test('does not fire while suppressed (fullscreen video)', () async {
    final scheduler = ReminderScheduler(settings: _settings(reminderIntervalMinutes: 1));
    final fired = <ReminderRequest>[];
    scheduler.reminderDue.listen(fired.add);

    scheduler.observe(_snapshot(continuousActiveSeconds: 60, currentApp: _fullscreenVideoApp));
    await _flushMicrotasks();
    expect(fired, isEmpty);
  });

  test('does not double-fire while a reminder is already open', () async {
    final scheduler = ReminderScheduler(settings: _settings(reminderIntervalMinutes: 1));
    final fired = <ReminderRequest>[];
    scheduler.reminderDue.listen(fired.add);

    scheduler.observe(_snapshot(continuousActiveSeconds: 60));
    scheduler.observe(_snapshot(continuousActiveSeconds: 61));
    scheduler.observe(_snapshot(continuousActiveSeconds: 62));
    await _flushMicrotasks();
    expect(fired, hasLength(1));
  });

  test('fires again after markReminderClosed once the threshold is crossed again', () async {
    final scheduler = ReminderScheduler(settings: _settings(reminderIntervalMinutes: 1));
    final fired = <ReminderRequest>[];
    scheduler.reminderDue.listen(fired.add);

    scheduler.observe(_snapshot(continuousActiveSeconds: 60));
    await _flushMicrotasks();
    scheduler.markReminderClosed();

    // Continuous seconds reset to 0 by TrackingEngine.resetContinuous(),
    // then climb back up to the threshold again.
    scheduler.observe(_snapshot(continuousActiveSeconds: 60));
    await _flushMicrotasks();

    expect(fired, hasLength(2));
  });
}
