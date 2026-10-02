import '../models/app_category.dart';
import '../models/daily_usage.dart';

/// One bar's worth of stacked category seconds. Deliberately carries no
/// display label — labeling (hour numbers, weekday names) is presentation
/// concern that belongs in ui/, formatted with the user's locale.
class ChartBucket {
  const ChartBucket({required this.secondsByCategory, required this.totalSeconds});

  final Map<AppCategory, int> secondsByCategory;
  final int totalSeconds;
}

class ChartData {
  const ChartData({required this.buckets, required this.axisMaxSeconds, required this.totalSeconds, this.averageSeconds});

  final List<ChartBucket> buckets;
  final int axisMaxSeconds;

  /// Sum of every bucket's [ChartBucket.totalSeconds] — the single source
  /// of truth for the period-total display, so callers never need to
  /// re-fold [buckets] themselves.
  final int totalSeconds;

  /// Average total seconds per bucket — only set for weekly charts
  /// (functional spec section 5's average line).
  final int? averageSeconds;
}

/// Daily view: 24 hourly buckets, fixed 1-hour (3600s) axis so bar height
/// is directly comparable across different days.
ChartData buildDailyChartData(DailyUsage usage) {
  final buckets = List.generate(24, (hour) {
    final byCategory = Map<AppCategory, int>.of(usage.hourlyCategorySeconds[hour] ?? const {});
    final total = byCategory.values.fold(0, (a, b) => a + b);
    return ChartBucket(secondsByCategory: byCategory, totalSeconds: total);
  });
  final totalSeconds = buckets.fold(0, (sum, b) => sum + b.totalSeconds);
  return ChartData(buckets: buckets, axisMaxSeconds: 3600, totalSeconds: totalSeconds);
}

/// Weekly view: one bucket per supplied day (each day's hourly buckets
/// summed into a daily total per category). Axis max rounds up to the
/// next full hour above `max(average, busiest day)`, never below 1 hour.
ChartData buildWeeklyChartData(List<DailyUsage> days) {
  final buckets = days.map((usage) {
    final byCategory = <AppCategory, int>{};
    for (final hourMap in usage.hourlyCategorySeconds.values) {
      hourMap.forEach((category, seconds) {
        byCategory[category] = (byCategory[category] ?? 0) + seconds;
      });
    }
    final total = byCategory.values.fold(0, (a, b) => a + b);
    return ChartBucket(secondsByCategory: byCategory, totalSeconds: total);
  }).toList();

  final totalSeconds = buckets.fold(0, (sum, b) => sum + b.totalSeconds);
  final average = buckets.isEmpty ? 0 : totalSeconds ~/ buckets.length;
  final maxDay = buckets.isEmpty ? 0 : buckets.map((b) => b.totalSeconds).reduce((a, b) => a > b ? a : b);
  final axisMax = _roundUpToHour(average > maxDay ? average : maxDay);

  return ChartData(buckets: buckets, axisMaxSeconds: axisMax, totalSeconds: totalSeconds, averageSeconds: average);
}

int _roundUpToHour(int seconds) {
  const hour = 3600;
  if (seconds <= 0) return hour;
  return ((seconds + hour - 1) ~/ hour) * hour;
}
