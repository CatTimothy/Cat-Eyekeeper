import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_category.dart';
import 'app_usage.dart';
import 'date_stamp.dart';
import 'reminder_event.dart';

part 'daily_usage.freezed.dart';
part 'daily_usage.g.dart';

DateTime _dateFromJson(String value) => parseDateStamp(value);

String _dateToJson(DateTime value) => formatDateStamp(value);

Map<int, Map<AppCategory, int>> _hourlyCategorySecondsFromJson(Map<String, dynamic>? json) {
  if (json == null) return const {};
  return json.map((hourKey, categoryMap) {
    final inner = (categoryMap as Map<String, dynamic>).map(
      (categoryKey, seconds) => MapEntry(appCategoryFromJson(categoryKey), seconds as int),
    );
    return MapEntry(int.parse(hourKey), inner);
  });
}

Map<String, dynamic> _hourlyCategorySecondsToJson(Map<int, Map<AppCategory, int>> value) => value.map(
  (hour, categoryMap) =>
      MapEntry(hour.toString(), categoryMap.map((category, seconds) => MapEntry(appCategoryToJson(category), seconds))),
);

/// One calendar day's usage record: per-app totals, an hour-of-day ×
/// category breakdown (for the dashboard chart), and any reminders that
/// fired that day. Persisted one file per day by data/usage_repository.dart.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class DailyUsage with _$DailyUsage {
  const factory DailyUsage({
    @Default(1) int version,

    /// Local calendar date this record covers, normalized to midnight.
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson) required DateTime date,
    @Default(0) int totalActiveSeconds,
    @Default(0) int continuousActiveSeconds,

    /// Keyed by ForegroundApp.appId.
    @Default({}) Map<String, AppUsage> apps,

    /// Outer key: local hour of day (0-23). Inner key: category.
    @JsonKey(fromJson: _hourlyCategorySecondsFromJson, toJson: _hourlyCategorySecondsToJson)
    @Default({})
    Map<int, Map<AppCategory, int>> hourlyCategorySeconds,
    @Default([]) List<ReminderEvent> reminders,
  }) = _DailyUsage;

  factory DailyUsage.fromJson(Map<String, dynamic> json) => _$DailyUsageFromJson(json);
}
