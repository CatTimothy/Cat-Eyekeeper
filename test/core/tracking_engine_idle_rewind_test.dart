// The idle-tail-rewind algorithm is the single easiest piece of this app
// to get subtly wrong: because idle state is only detected once
// idleThresholdSeconds have elapsed with no input, the active->idle
// transition tick must retroactively subtract that trailing over-count.
// Skipping it silently inflates every day's totals. See functional spec
// section 1 and core/tracking_engine.dart's `_rewindIdleTail`.

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/category_classifier.dart';
import 'package:cat_eyekeeper/domain/use_cases/idle_detector.dart';
import 'package:cat_eyekeeper/domain/use_cases/tracking_engine.dart';
import 'package:cat_eyekeeper/domain/models/app_category.dart';
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
const _codeAppId = 'C:\\apps\\code.exe';

void main() {
  late DateTime clock;
  late FakeIdleReader idleReader;
  late FakeForegroundReader foregroundReader;
  late TrackingEngine engine;

  setUp(() {
    clock = DateTime(2026, 7, 15, 10, 0, 0);
    idleReader = FakeIdleReader();
    foregroundReader = FakeForegroundReader(app: _codeApp);
    final settings = Settings.defaults().copyWith(idleThresholdSeconds: 60);
    engine = TrackingEngine(
      idleDetector: IdleDetector([idleReader]),
      foregroundReader: foregroundReader,
      classifier: CategoryClassifier(CategoryRules.defaults()),
      usageRepository: InMemoryUsageRepository(),
      settings: settings,
      initialUsage: DailyUsage(date: DateTime(2026, 7, 15)),
      now: () => clock,
    );
  });

  Future<void> tickActive() async {
    clock = clock.add(const Duration(seconds: 1));
    idleReader.idleDuration = Duration.zero;
    await engine.tick();
  }

  Future<void> tickIdle(Duration idleDuration) async {
    clock = clock.add(const Duration(seconds: 1));
    idleReader.idleDuration = idleDuration;
    await engine.tick();
  }

  test('accumulates one active second per tick while active', () async {
    for (var i = 0; i < 10; i++) {
      await tickActive();
    }

    final usage = engine.currentUsage;
    expect(usage.totalActiveSeconds, 10);
    expect(usage.continuousActiveSeconds, 10);
    expect(usage.apps[_codeAppId]!.activeSeconds, 10);
  });

  test('rewinds exactly idleThresholdSeconds off total/continuous/app seconds on the active->idle transition', () async {
    for (var i = 0; i < 100; i++) {
      await tickActive();
    }

    // One tick where idle time has already reached the 60s threshold:
    // isActive flips false and the rewind fires.
    await tickIdle(const Duration(seconds: 60));

    final usage = engine.currentUsage;
    expect(usage.totalActiveSeconds, 40); // 100 - 60
    expect(usage.continuousActiveSeconds, 40);
    expect(usage.apps[_codeAppId]!.activeSeconds, 40);
    expect(usage.hourlyCategorySeconds[10]![AppCategory.work], 40);
  });

  test('rewind is capped at the seconds actually accumulated and never goes negative', () async {
    for (var i = 0; i < 10; i++) {
      await tickActive();
    }

    await tickIdle(const Duration(seconds: 60));

    final usage = engine.currentUsage;
    expect(usage.totalActiveSeconds, 0);
    expect(usage.continuousActiveSeconds, 0);
    expect(usage.apps[_codeAppId]!.activeSeconds, 0);
    expect(usage.hourlyCategorySeconds[10]?[AppCategory.work] ?? 0, 0);
  });

  test('lastUsedAt is rewound but clamped to never precede firstUsedAt', () async {
    for (var i = 0; i < 5; i++) {
      await tickActive();
    }
    final lastActiveTick = clock;

    await tickIdle(const Duration(seconds: 60));

    final app = engine.currentUsage.apps[_codeAppId]!;
    expect(app.lastUsedAt.isBefore(app.firstUsedAt), isFalse);
    expect(app.lastUsedAt.isBefore(lastActiveTick), isTrue);
  });

  test('a genuine pause does not trigger a rewind (only a passive idle transition does)', () async {
    for (var i = 0; i < 10; i++) {
      await tickActive();
    }

    engine.pause();
    clock = clock.add(const Duration(seconds: 1));
    await engine.tick();

    expect(engine.currentUsage.totalActiveSeconds, 10); // unchanged, no rewind
  });

  test('rewind removes seconds from the correct hourly category bucket, including across an hour boundary', () async {
    // Start 3 seconds before the hour rolls over so the accumulated active
    // seconds span two hourly buckets.
    clock = DateTime(2026, 7, 15, 10, 59, 57);
    for (var i = 0; i < 6; i++) {
      await tickActive(); // ticks land at :58, :59, 11:00, :01, :02, :03
    }
    expect(engine.currentUsage.hourlyCategorySeconds[10]![AppCategory.work], 2);
    expect(engine.currentUsage.hourlyCategorySeconds[11]![AppCategory.work], 4);

    await tickIdle(const Duration(seconds: 60)); // rewinds all 6 accumulated seconds

    final usage = engine.currentUsage;
    expect(usage.totalActiveSeconds, 0);
    expect(usage.hourlyCategorySeconds[10]?[AppCategory.work] ?? 0, 0);
    expect(usage.hourlyCategorySeconds[11]?[AppCategory.work] ?? 0, 0);
  });
}
