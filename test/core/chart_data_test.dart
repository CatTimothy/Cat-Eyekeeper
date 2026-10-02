import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/chart_data.dart';
import 'package:cat_eyekeeper/domain/models/app_category.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';

void main() {
  test('daily chart data has 24 buckets with a fixed 1-hour axis max', () {
    final usage = DailyUsage(
      date: DateTime(2026, 7, 15),
      hourlyCategorySeconds: {
        9: {AppCategory.work: 1800},
        14: {AppCategory.entertainment: 900, AppCategory.social: 300},
      },
    );

    final chart = buildDailyChartData(usage);

    expect(chart.buckets, hasLength(24));
    expect(chart.axisMaxSeconds, 3600);
    expect(chart.averageSeconds, isNull);
    expect(chart.buckets[9].totalSeconds, 1800);
    expect(chart.buckets[14].totalSeconds, 1200);
    expect(chart.buckets[14].secondsByCategory[AppCategory.entertainment], 900);
    expect(chart.buckets[0].totalSeconds, 0); // untouched hour
  });

  test('weekly chart data sums each day\'s hours into one bucket per day', () {
    final monday = DailyUsage(
      date: DateTime(2026, 7, 13),
      hourlyCategorySeconds: {
        9: {AppCategory.work: 3600},
        10: {AppCategory.work: 1800},
      },
    );
    final tuesday = DailyUsage(
      date: DateTime(2026, 7, 14),
      hourlyCategorySeconds: {
        9: {AppCategory.entertainment: 900},
      },
    );

    final chart = buildWeeklyChartData([monday, tuesday]);

    expect(chart.buckets, hasLength(2));
    expect(chart.buckets[0].totalSeconds, 5400);
    expect(chart.buckets[0].secondsByCategory[AppCategory.work], 5400);
    expect(chart.buckets[1].totalSeconds, 900);
  });

  test('weekly axis max rounds up to the next full hour above the busier of average/max-day', () {
    final days = [
      DailyUsage(date: DateTime(2026, 7, 13), hourlyCategorySeconds: {9: {AppCategory.work: 7200}}), // 2h
      DailyUsage(date: DateTime(2026, 7, 14), hourlyCategorySeconds: {9: {AppCategory.work: 3600}}), // 1h
    ];

    final chart = buildWeeklyChartData(days);

    // average = 1.5h, max day = 2h -> axis should round up from 2h (7200s) -> already a full hour, stays 7200.
    expect(chart.averageSeconds, 5400);
    expect(chart.axisMaxSeconds, 7200);
  });

  test('weekly axis max is never below 1 hour even with no usage at all', () {
    final days = [DailyUsage(date: DateTime(2026, 7, 13)), DailyUsage(date: DateTime(2026, 7, 14))];

    final chart = buildWeeklyChartData(days);

    expect(chart.averageSeconds, 0);
    expect(chart.axisMaxSeconds, 3600);
  });

  test('weekly axis max rounds a partial-hour peak up to the next full hour', () {
    final days = [
      DailyUsage(date: DateTime(2026, 7, 13), hourlyCategorySeconds: {9: {AppCategory.work: 100}}),
    ];

    final chart = buildWeeklyChartData(days);

    expect(chart.axisMaxSeconds, 3600); // 100s rounds up to a full hour, not down to 0
  });
}
