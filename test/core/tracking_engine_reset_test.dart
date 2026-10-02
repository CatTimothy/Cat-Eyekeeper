import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/category_classifier.dart';
import 'package:cat_eyekeeper/domain/use_cases/idle_detector.dart';
import 'package:cat_eyekeeper/domain/use_cases/tracking_engine.dart';
import 'package:cat_eyekeeper/domain/models/category_rule.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';
import 'package:cat_eyekeeper/domain/models/foreground_app.dart';
import 'package:cat_eyekeeper/domain/models/settings.dart';

import '../data/fakes/in_memory_usage_repository.dart';
import '../platform/fakes/fake_foreground_reader.dart';
import '../platform/fakes/fake_idle_reader.dart';

final _codeApp = ForegroundApp(
  processId: 1,
  name: 'Visual Studio Code',
  processName: 'code',
  executablePath: 'C:\\apps\\code.exe',
  windowTitle: 'main.dart - Visual Studio Code',
  isFullScreen: false,
);

void main() {
  test('resetToday() zeroes all in-memory usage and persists the empty state', () async {
    var clock = DateTime(2026, 7, 15, 10, 0, 0);
    final idleReader = FakeIdleReader()..idleDuration = Duration.zero;
    final foregroundReader = FakeForegroundReader(app: _codeApp);
    final usageRepository = InMemoryUsageRepository();
    final engine = TrackingEngine(
      idleDetector: IdleDetector([idleReader]),
      foregroundReader: foregroundReader,
      classifier: CategoryClassifier(CategoryRules.defaults()),
      usageRepository: usageRepository,
      settings: Settings.defaults(),
      initialUsage: DailyUsage(date: DateTime(2026, 7, 15)),
      now: () => clock,
    );

    for (var i = 0; i < 10; i++) {
      clock = clock.add(const Duration(seconds: 1));
      await engine.tick();
    }
    expect(engine.currentUsage.totalActiveSeconds, 10);

    await engine.resetToday();

    final usage = engine.currentUsage;
    expect(usage.totalActiveSeconds, 0);
    expect(usage.continuousActiveSeconds, 0);
    expect(usage.apps, isEmpty);
    expect(usage.hourlyCategorySeconds, isEmpty);
    expect(usage.reminders, isEmpty);

    // The reset state was also persisted (not just held in memory).
    final persisted = await usageRepository.load(DateTime(2026, 7, 15));
    expect(persisted.totalActiveSeconds, 0);
  });

  test('startup zeroes the continuous streak even when persisted usage has one', () {
    final idleReader = FakeIdleReader()..idleDuration = Duration.zero;
    final foregroundReader = FakeForegroundReader(app: _codeApp);
    final engine = TrackingEngine(
      idleDetector: IdleDetector([idleReader]),
      foregroundReader: foregroundReader,
      classifier: CategoryClassifier(CategoryRules.defaults()),
      usageRepository: InMemoryUsageRepository(),
      settings: Settings.defaults(),
      // Simulates resuming a session from disk after a restart: today's
      // total survived, but the app was closed for however long in
      // between, so the continuous-active streak should not resume too.
      initialUsage: DailyUsage(date: DateTime(2026, 7, 15), totalActiveSeconds: 600, continuousActiveSeconds: 600),
      now: () => DateTime(2026, 7, 15, 10, 0, 0),
    );

    expect(engine.currentUsage.totalActiveSeconds, 600);
    expect(engine.currentUsage.continuousActiveSeconds, 0);
  });
}
