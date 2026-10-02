import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/models/app_category.dart';
import 'package:cat_eyekeeper/domain/models/app_usage.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';
import 'package:cat_eyekeeper/domain/models/date_stamp.dart';
import 'package:cat_eyekeeper/domain/models/reminder_event.dart';

void main() {
  test('DailyUsage round-trips including nested hourlyCategorySeconds and apps', () {
    final date = DateTime(2026, 7, 15);
    final original = DailyUsage(
      date: date,
      totalActiveSeconds: 3661,
      continuousActiveSeconds: 120,
      apps: {
        'C:\\apps\\code.exe': AppUsage(
          name: 'Visual Studio Code',
          processName: 'code',
          executablePath: 'C:\\apps\\code.exe',
          category: AppCategory.work,
          activeSeconds: 3600,
          firstUsedAt: DateTime(2026, 7, 15, 9),
          lastUsedAt: DateTime(2026, 7, 15, 10),
        ),
      },
      hourlyCategorySeconds: {
        9: {AppCategory.work: 3000, AppCategory.entertainment: 200},
        10: {AppCategory.social: 100},
      },
      reminders: [
        ReminderEvent(
          triggeredAt: DateTime(2026, 7, 15, 9, 45),
          continuousActiveSeconds: 2700,
          action: 'completed',
        ),
      ],
    );

    final decoded = DailyUsage.fromJson(original.toJson());

    expect(decoded.date, date);
    expect(decoded.totalActiveSeconds, 3661);
    expect(decoded.apps['C:\\apps\\code.exe']!.activeSeconds, 3600);
    expect(decoded.hourlyCategorySeconds[9]![AppCategory.work], 3000);
    expect(decoded.hourlyCategorySeconds[9]![AppCategory.entertainment], 200);
    expect(decoded.hourlyCategorySeconds[10]![AppCategory.social], 100);
    expect(decoded.reminders.single.action, 'completed');
  });

  test('date stamp helpers round-trip a local calendar date', () {
    final date = DateTime(2026, 1, 5);
    expect(formatDateStamp(date), '2026-01-05');
    expect(parseDateStamp('2026-01-05'), date);
  });
}
