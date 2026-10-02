import 'dart:typed_data';

import '../../../data/repositories/usage_repository.dart';
import '../../../data/services/platform/app_icon_reader.dart';
import '../../../data/services/platform/platform_factory.dart';
import '../../../di/injection.dart';
import '../../../domain/models/app_category.dart';
import '../../../domain/models/daily_usage.dart';
import '../../../domain/models/date_stamp.dart';
import '../../../domain/models/usage_snapshot.dart';
import '../../../domain/use_cases/chart_data.dart';
import '../../../domain/use_cases/tracking_engine.dart';
import '../../core/base_view_model.dart';

export '../../../domain/use_cases/chart_data.dart' show ChartBucket, ChartData;

enum ChartViewMode { daily, weekly }

/// Which period the dashboard chart is showing, and navigation between
/// periods (functional spec section 5: daily/weekly toggle, prev/next,
/// never past today).
class DashboardPeriod {
  const DashboardPeriod({required this.mode, required this.anchorDate});

  final ChartViewMode mode;

  /// The day being viewed (daily mode), or any day within the viewed
  /// week (weekly mode) — the week itself is Monday..Sunday containing
  /// this date.
  final DateTime anchorDate;
}

/// One row of the app usage list (functional spec section 5).
class AppUsageSummary {
  const AppUsageSummary({
    required this.appId,
    required this.name,
    required this.category,
    required this.totalSeconds,
    required this.dailyAverageSeconds,
    required this.shareOfTotal,
  });

  final String appId;
  final String name;
  final AppCategory category;
  final int totalSeconds;

  /// Total seconds across the loaded period divided by the number of
  /// days loaded — equals [totalSeconds] itself in daily view.
  final int dailyAverageSeconds;

  /// 0.0-1.0 share of the period's total tracked time across all apps.
  final double shareOfTotal;
}

class _Accumulator {
  String name = '';
  AppCategory category = AppCategory.other;
  int totalSeconds = 0;
}

DateTime _mondayOf(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

/// Owns everything the dashboard screen shows: the daily/weekly period
/// being viewed, the category filter, the per-app usage list, and the
/// chart data — combining historical days loaded from disk with today's
/// live [TrackingEngine] snapshot, spliced in so the display keeps
/// updating in real time without re-reading disk every tick. Screen-scoped
/// (constructed fresh each time the dashboard is shown — see
/// ui/dashboard/dashboard_screen.dart), which is also why nothing needs an
/// explicit "invalidate" signal when Settings' "clear data" action deletes
/// history out from under it: this app shows one screen at a time, so a
/// fresh instance always reloads from disk the next time the dashboard
/// becomes visible.
class DashboardViewModel extends BaseViewModel {
  DashboardViewModel({UsageRepository? usageRepository, TrackingEngine? trackingEngine, AppIconReader? appIconReader})
    : _usageRepository = usageRepository ?? getIt<UsageRepository>(),
      _trackingEngine = trackingEngine ?? getIt<TrackingEngine>(),
      _appIconReader = appIconReader ?? getIt<PlatformServices>().appIconReader {
    _reload();
    addSubscription(_trackingEngine.snapshots.listen(_onSnapshot));
  }

  final UsageRepository _usageRepository;
  final TrackingEngine _trackingEngine;
  final AppIconReader _appIconReader;

  DashboardPeriod _period = DashboardPeriod(mode: ChartViewMode.daily, anchorDate: dateOnly(DateTime.now()));
  DashboardPeriod get period => _period;

  AppCategory? _categoryFilter;
  AppCategory? get categoryFilter => _categoryFilter;

  /// Null while the period's days are still loading from disk (period
  /// navigation, or the first load) — Views show a spinner in that state,
  /// mirroring the old `AsyncValue.loading()` branch.
  List<DailyUsage>? _days;

  bool get isLoading => _days == null;

  ChartData? get chartData {
    final days = _days;
    if (days == null || days.isEmpty) return null;
    return _period.mode == ChartViewMode.daily ? buildDailyChartData(days.first) : buildWeeklyChartData(days);
  }

  /// Per-app totals for the current period, filtered by [categoryFilter]
  /// and sorted by usage descending.
  List<AppUsageSummary>? get appUsageList {
    final days = _days;
    if (days == null) return null;

    final byApp = <String, _Accumulator>{};
    for (final day in days) {
      for (final entry in day.apps.entries) {
        final acc = byApp.putIfAbsent(entry.key, _Accumulator.new);
        acc.name = entry.value.name;
        acc.category = entry.value.category;
        acc.totalSeconds += entry.value.activeSeconds;
      }
    }

    final grandTotal = byApp.values.fold(0, (sum, a) => sum + a.totalSeconds);
    final dayCount = days.isEmpty ? 1 : days.length;
    final filter = _categoryFilter;

    return byApp.entries
        .map(
          (entry) => AppUsageSummary(
            appId: entry.key,
            name: entry.value.name,
            category: entry.value.category,
            totalSeconds: entry.value.totalSeconds,
            dailyAverageSeconds: entry.value.totalSeconds ~/ dayCount,
            shareOfTotal: grandTotal == 0 ? 0 : entry.value.totalSeconds / grandTotal,
          ),
        )
        .where((summary) => filter == null || summary.category == filter)
        .toList()
      ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
  }

  /// Total seconds per category across the whole period (unfiltered),
  /// powering the clickable category legend chips.
  Map<AppCategory, int>? get categoryTotals {
    final days = _days;
    if (days == null) return null;
    final totals = <AppCategory, int>{};
    for (final day in days) {
      for (final usage in day.apps.values) {
        totals[usage.category] = (totals[usage.category] ?? 0) + usage.activeSeconds;
      }
    }
    return totals;
  }

  void setPeriodMode(ChartViewMode mode) {
    if (mode == _period.mode) return;
    _period = DashboardPeriod(mode: mode, anchorDate: dateOnly(DateTime.now()));
    _reload();
  }

  void goToPreviousPeriod() {
    final delta = _period.mode == ChartViewMode.daily ? 1 : 7;
    _period = DashboardPeriod(mode: _period.mode, anchorDate: _period.anchorDate.subtract(Duration(days: delta)));
    _reload();
  }

  void goToNextPeriod() {
    if (!canGoNext) return;
    final delta = _period.mode == ChartViewMode.daily ? 1 : 7;
    final next = _period.anchorDate.add(Duration(days: delta));
    final today = dateOnly(DateTime.now());
    _period = DashboardPeriod(mode: _period.mode, anchorDate: next.isAfter(today) ? today : next);
    _reload();
  }

  bool get canGoNext => _period.anchorDate.isBefore(dateOnly(DateTime.now()));

  void toggleCategoryFilter(AppCategory category) {
    _categoryFilter = _categoryFilter == category ? null : category;
    safeNotifyListeners();
  }

  void clearCategoryFilter() {
    if (_categoryFilter == null) return;
    _categoryFilter = null;
    safeNotifyListeners();
  }

  /// The app's real icon (e.g. what Explorer shows), keyed by executable
  /// path — null falls back to a letter avatar (functional spec's
  /// dashboard app list). [AppIconReader] caches internally, so this is
  /// cheap after the first read for a given path.
  Uint8List? appIconFor(String executablePath) => _appIconReader.read(executablePath);

  /// Loads the period's days fresh from disk — one day for daily mode, up
  /// to 7 (Mon..Sun, truncated at today) for weekly mode.
  Future<void> _reload() async {
    _days = null;
    safeNotifyListeners();

    final today = dateOnly(DateTime.now());
    final List<DailyUsage> loaded;
    if (_period.mode == ChartViewMode.daily) {
      loaded = [await _usageRepository.loadExistingOrEmpty(_period.anchorDate)];
    } else {
      final weekStart = _mondayOf(_period.anchorDate);
      final days = <DailyUsage>[];
      for (var i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        if (date.isAfter(today)) break;
        days.add(await _usageRepository.loadExistingOrEmpty(date));
      }
      loaded = days;
    }

    _days = loaded;
    _spliceLiveSnapshot();
    safeNotifyListeners();
  }

  /// Replaces today's entry (if it's part of the currently-loaded days)
  /// with the live tracking snapshot, so the chart/list keep updating in
  /// real time without re-reading disk on every tick.
  void _spliceLiveSnapshot() {
    final days = _days;
    final live = _liveTodayUsage;
    if (days == null || live == null) return;
    final today = dateOnly(DateTime.now());
    _days = [for (final day in days) day.date == today ? live : day];
  }

  DailyUsage? _liveTodayUsage;

  /// The most recent snapshot straight from [TrackingEngine] — the stat
  /// cards' source (today's total/continuous seconds, active/paused
  /// state, idle time), as opposed to [_days], which only carries the
  /// `DailyUsage` portion and only for whichever day(s) the chart/app
  /// list are currently showing.
  UsageSnapshot? _liveSnapshot;
  UsageSnapshot? get liveSnapshot => _liveSnapshot;

  void _onSnapshot(UsageSnapshot snapshot) {
    _liveSnapshot = snapshot;
    _liveTodayUsage = snapshot.todayUsage;
    _spliceLiveSnapshot();
    safeNotifyListeners();
  }
}
