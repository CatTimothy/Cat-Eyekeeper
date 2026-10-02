import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder_event.freezed.dart';
part 'reminder_event.g.dart';

/// A log entry for one break-reminder occurrence, kept alongside a day's
/// usage record. See core/reminder_scheduler.dart for how these are raised.
@freezed
abstract class ReminderEvent with _$ReminderEvent {
  const factory ReminderEvent({
    @Default('break') String type,
    required DateTime triggeredAt,

    /// The continuous-active-seconds value at the moment the reminder fired,
    /// captured before the counter is reset.
    required int continuousActiveSeconds,

    /// How the reminder ended: 'completed' (countdown ran out) or 'closed'
    /// (user dismissed early, only possible when allowed by settings).
    required String action,
  }) = _ReminderEvent;

  factory ReminderEvent.fromJson(Map<String, dynamic> json) => _$ReminderEventFromJson(json);
}
