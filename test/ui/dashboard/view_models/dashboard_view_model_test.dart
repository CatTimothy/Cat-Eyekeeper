import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/models/app_category.dart';
import 'package:cat_eyekeeper/domain/models/category_rule.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';
import 'package:cat_eyekeeper/domain/models/date_stamp.dart';
import 'package:cat_eyekeeper/domain/models/foreground_app.dart';
import 'package:cat_eyekeeper/domain/models/settings.dart';
import 'package:cat_eyekeeper/domain/use_cases/category_classifier.dart';
import 'package:cat_eyekeeper/domain/use_cases/idle_detector.dart';
import 'package:cat_eyekeeper/domain/use_cases/tracking_engine.dart';
import 'package:cat_eyekeeper/data/services/platform/app_icon_reader.dart';
import 'package:cat_eyekeeper/ui/dashboard/view_models/dashboard_view_model.dart';

import '../../../data/fakes/in_memory_usage_repository.dart';
import '../../../platform/fakes/fake_foreground_reader.dart';
import '../../../platform/fakes/fake_idle_reader.dart';

class _NullAppIconReader implements AppIconReader {
  @override
  Uint8List? read(String executablePath) => null;
}

final _codeApp = ForegroundApp(
  processId: 1,
  name: 'Visual Studio Code',
  processName: 'code',
  executablePath: 'C:\\apps\\code.exe',
  windowTitle: 'main.dart - Visual Studio Code',
  isFullScreen: false,
);

void main() {
  late DateTime clock;
  late TrackingEngine engine;
  late InMemoryUsageRepository usageRepository;

  TrackingEngine buildEngine() {
    final idleReader = FakeIdleReader()..idleDuration = Duration.zero;
    final foregroundReader = FakeForegroundReader(app: _codeApp);
    usageRepository = InMemoryUsageRepository();
    return TrackingEngine(
      idleDetector: IdleDetector([idleReader]),
      foregroundReader: foregroundReader,
      classifier: CategoryClassifier(CategoryRules.defaults()),
      usageRepository: usageRepository,
      settings: Settings.defaults(),
      initialUsage: DailyUsage(date: dateOnly(clock)),
      now: () => clock,
    );
  }

  setUp(() {
    // DashboardViewModel itself has no injectable clock — it always
    // compares against the real DateTime.now() (matching production,
    // where TrackingEngine's real clock and "today" always agree). Start
    // from the real now() here too, so TrackingEngine's fake-but-advancing
    // clock stays on the same calendar day the ViewModel is comparing
    // against, instead of drifting onto a different day and silently
    // breaking the live-snapshot splice (which keys off same-day dates).
    clock = DateTime.now();
    engine = buildEngine();
  });

  test('starts loading, then resolves an empty daily period for today', () async {
    final viewModel = DashboardViewModel(usageRepository: usageRepository, trackingEngine: engine, appIconReader: _NullAppIconReader());
    addTearDown(viewModel.dispose);

    expect(viewModel.isLoading, isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.period.mode, ChartViewMode.daily);
    expect(viewModel.chartData, isNotNull);
    expect(viewModel.appUsageList, isEmpty);
  });

  test('a tracking-engine tick splices live usage into today without touching disk', () async {
    final viewModel = DashboardViewModel(usageRepository: usageRepository, trackingEngine: engine, appIconReader: _NullAppIconReader());
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    for (var i = 0; i < 5; i++) {
      clock = clock.add(const Duration(seconds: 1));
      await engine.tick();
      // TrackingEngine's snapshot stream is a non-sync broadcast
      // controller, so `.add()` delivers to listeners on a later
      // microtask rather than synchronously within tick() — drain it
      // before the next tick so DashboardViewModel's subscription has
      // definitely processed this one first.
      await Future<void>.delayed(Duration.zero);
    }

    expect(viewModel.liveSnapshot?.todayUsage.totalActiveSeconds, 5);
    final list = viewModel.appUsageList!;
    expect(list, hasLength(1));
    expect(list.single.appId, 'C:\\apps\\code.exe');
    expect(list.single.totalSeconds, 5);
    expect(list.single.category, AppCategory.work);
  });

  test('goToNextPeriod cannot advance past today', () async {
    final viewModel = DashboardViewModel(usageRepository: usageRepository, trackingEngine: engine, appIconReader: _NullAppIconReader());
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.canGoNext, isFalse);
    viewModel.goToNextPeriod();
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.period.anchorDate, dateOnly(DateTime.now()));
  });

  test('goToPreviousPeriod then goToNextPeriod returns to today, re-enabling canGoNext=false', () async {
    final viewModel = DashboardViewModel(usageRepository: usageRepository, trackingEngine: engine, appIconReader: _NullAppIconReader());
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.goToPreviousPeriod();
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.canGoNext, isTrue);

    viewModel.goToNextPeriod();
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.canGoNext, isFalse);
    expect(viewModel.period.anchorDate, dateOnly(DateTime.now()));
  });

  test('toggleCategoryFilter selects then clears on a second toggle of the same category', () async {
    final viewModel = DashboardViewModel(usageRepository: usageRepository, trackingEngine: engine, appIconReader: _NullAppIconReader());
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.toggleCategoryFilter(AppCategory.work);
    expect(viewModel.categoryFilter, AppCategory.work);

    viewModel.toggleCategoryFilter(AppCategory.work);
    expect(viewModel.categoryFilter, isNull);
  });

  test('appUsageList excludes categories that do not match an active filter', () async {
    final viewModel = DashboardViewModel(usageRepository: usageRepository, trackingEngine: engine, appIconReader: _NullAppIconReader());
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    clock = clock.add(const Duration(seconds: 1));
    await engine.tick();

    viewModel.toggleCategoryFilter(AppCategory.social);
    expect(viewModel.appUsageList, isEmpty);

    viewModel.toggleCategoryFilter(AppCategory.social);
    viewModel.toggleCategoryFilter(AppCategory.work);
    expect(viewModel.appUsageList, hasLength(1));
  });
}
