import 'dart:async';

import '../models/reminder_request.dart';
import '../models/settings.dart';
import '../models/usage_snapshot.dart';
import 'reminder_guard.dart';

/// The break-reminder threshold, in seconds, derived from
/// [Settings.reminderIntervalMinutes] — clamped to at least 1 second so a
/// misconfigured or hand-edited zero/negative interval can't produce a
/// non-firing (or negative) threshold. The single source of truth for this
/// calculation: anything that needs to know when a reminder will fire
/// (this scheduler, and the dashboard's "next break" stat card) reads this
/// rather than re-deriving the formula itself.
int reminderThresholdSeconds(Settings settings) {
  final rawThreshold = settings.reminderIntervalMinutes * 60;
  return rawThreshold < 1 ? 1 : rawThreshold;
}

/// Watches usage snapshots and raises a [ReminderRequest] once continuous
/// active time crosses the configured threshold and isn't suppressed
/// (functional spec section 3). Purely reactive — call [observe] with
/// every snapshot from TrackingEngine.snapshots; it owns no timer of its
/// own, so it fires at whatever cadence the caller feeds it.
class ReminderScheduler {
  ReminderScheduler({required Settings settings}) : _settings = settings;

  Settings _settings;
  bool _isReminderOpen = false;

  final _dueController = StreamController<ReminderRequest>.broadcast();

  Stream<ReminderRequest> get reminderDue => _dueController.stream;

  /// The most recently raised request — lets a late subscriber (the
  /// reminder overlay, mounted only after ui/shell/app_shell.dart reacts
  /// to this same event) read what triggered the current reminder without
  /// this class needing to pipe the request through the window-shell
  /// state that actually drives the overlay's visibility.
  ReminderRequest? lastRequest;

  void updateSettings(Settings settings) => _settings = settings;

  void observe(UsageSnapshot snapshot) {
    if (_isReminderOpen) return;
    if (!_settings.reminderEnabled) return;
    if (snapshot.isPaused) return;

    final continuousSeconds = snapshot.todayUsage.continuousActiveSeconds;
    if (continuousSeconds <= 0) return;

    final thresholdSeconds = reminderThresholdSeconds(_settings);
    if (continuousSeconds < thresholdSeconds) return;

    if (suppressReminder(snapshot.currentApp) != null) return;

    _isReminderOpen = true;
    final request = ReminderRequest(usage: snapshot.todayUsage, thresholdSeconds: thresholdSeconds, currentApp: snapshot.currentApp);
    lastRequest = request;
    _dueController.add(request);
  }

  /// Call once the reminder overlay has been dismissed, so a future
  /// snapshot crossing the threshold again can raise a new reminder.
  void markReminderClosed() => _isReminderOpen = false;

  Future<void> dispose() => _dueController.close();
}
