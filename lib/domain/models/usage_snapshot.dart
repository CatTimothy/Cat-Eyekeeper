import 'package:freezed_annotation/freezed_annotation.dart';

import 'daily_usage.dart';
import 'foreground_app.dart';

part 'usage_snapshot.freezed.dart';

/// Published once per tick by core/tracking_engine.dart's
/// `Stream<UsageSnapshot>`. Every subscriber (dashboard, reminder scheduler,
/// tray) reads the same snapshot independently.
@freezed
abstract class UsageSnapshot with _$UsageSnapshot {
  const factory UsageSnapshot({
    required DailyUsage todayUsage,
    ForegroundApp? currentApp,
    required bool isActive,
    required bool isPaused,
    required Duration idleTime,
    required DateTime updatedAt,
  }) = _UsageSnapshot;
}
