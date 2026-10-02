import 'package:freezed_annotation/freezed_annotation.dart';

import 'daily_usage.dart';
import 'foreground_app.dart';

part 'reminder_request.freezed.dart';

/// Raised by core/reminder_scheduler.dart when continuous active time
/// crosses the configured threshold and isn't suppressed.
@freezed
abstract class ReminderRequest with _$ReminderRequest {
  const factory ReminderRequest({required DailyUsage usage, required int thresholdSeconds, ForegroundApp? currentApp}) =
      _ReminderRequest;
}
