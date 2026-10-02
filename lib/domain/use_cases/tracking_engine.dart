import 'dart:async';

import '../../data/repositories/usage_repository.dart';
import '../models/app_category.dart';
import '../models/app_usage.dart';
import '../models/daily_usage.dart';
import '../models/date_stamp.dart';
import '../models/foreground_app.dart';
import '../models/reminder_event.dart';
import '../models/settings.dart';
import '../models/usage_snapshot.dart';
import '../../data/services/platform/foreground_reader.dart';
import 'category_classifier.dart';
import 'idle_detector.dart';

/// The app's single source of truth: a 1-second ticker that tracks the
/// foreground app, accumulates active seconds, and publishes a
/// [UsageSnapshot] every tick on a broadcast stream. Every other part of
/// the app (dashboard, reminder scheduler, tray) subscribes independently
/// — this class doesn't know or care who's listening.
///
/// Functional spec section 1.
class TrackingEngine {
  TrackingEngine({
    required IdleDetector idleDetector,
    required ForegroundReader foregroundReader,
    required CategoryClassifier classifier,
    required UsageRepository usageRepository,
    required Settings settings,
    required DailyUsage initialUsage,
    DateTime Function()? now,
  }) : _idleDetector = idleDetector,
       _foregroundReader = foregroundReader,
       _classifier = classifier,
       _usageRepository = usageRepository,
       _settings = settings,
       _now = now ?? DateTime.now {
    _loadWorkingState(initialUsage);
    // The persisted streak belongs to whatever session was running before
    // this process started — the app may have been closed (or the machine
    // asleep) for hours in between, so resuming it here could fire a break
    // reminder within seconds of a fresh launch. Only today's *total* is
    // meant to survive a restart; the continuous streak always starts at
    // zero on (re)start, same as it already does on the same-day rollover
    // path in [tick].
    _continuousActiveSeconds = 0;
    _nextSaveAt = _alignToNextFiveMinute(_now());
  }

  final IdleDetector _idleDetector;
  final ForegroundReader _foregroundReader;
  final CategoryClassifier _classifier;
  final UsageRepository _usageRepository;
  final DateTime Function() _now;
  Settings _settings;

  late DateTime _date;
  late int _totalActiveSeconds;
  late int _continuousActiveSeconds;
  late Map<String, AppUsage> _apps;
  late Map<int, Map<AppCategory, int>> _hourlyCategorySeconds;
  late List<ReminderEvent> _reminders;

  bool _wasActive = false;
  bool _isPaused = false;
  bool _isSaving = false;
  bool _isTicking = false;
  String? _lastAppId;
  AppCategory _lastActiveCategory = AppCategory.other;
  late DateTime _nextSaveAt;

  Timer? _timer;
  final _snapshotController = StreamController<UsageSnapshot>.broadcast();

  Stream<UsageSnapshot> get snapshots => _snapshotController.stream;

  /// Synchronous read of the working state, e.g. to seed UI before the
  /// first tick's snapshot arrives, or for tests to assert on directly
  /// (snapshots is a broadcast stream, so a late listener misses history).
  DailyUsage get currentUsage => _buildSnapshotUsage();

  void updateSettings(Settings settings) => _settings = settings;

  void start() {
    _nextSaveAt = _alignToNextFiveMinute(_now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  /// Stops the ticker and flushes a final save.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _save();
  }

  /// No accumulation happens while paused; the tick loop keeps running
  /// (and publishing snapshots) so the UI still reflects "paused" state.
  void pause() {
    _isPaused = true;
    _lastAppId = null;
  }

  void resume() => _isPaused = false;

  /// Called when a break reminder ends: logs the outcome and zeroes the
  /// continuous-active counter.
  Future<void> resetContinuous(String action) async {
    _reminders = [
      ..._reminders,
      ReminderEvent(triggeredAt: _now(), continuousActiveSeconds: _continuousActiveSeconds, action: action),
    ];
    _continuousActiveSeconds = 0;
    await _save();
  }

  /// Zeroes today's in-memory usage after Settings' "clear data" action
  /// deletes the on-disk history, and saves so it's durable immediately
  /// rather than waiting for the next five-minute autosave. The next tick
  /// (the ticker keeps running) publishes the zeroed snapshot within ~1s.
  Future<void> resetToday() async {
    _totalActiveSeconds = 0;
    _continuousActiveSeconds = 0;
    _apps = {};
    _hourlyCategorySeconds = {};
    _reminders = [];
    _lastAppId = null;
    await _save();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _snapshotController.close();
  }

  void _loadWorkingState(DailyUsage usage) {
    _date = usage.date;
    _totalActiveSeconds = usage.totalActiveSeconds;
    _continuousActiveSeconds = usage.continuousActiveSeconds;
    _apps = Map.of(usage.apps);
    _hourlyCategorySeconds = {
      for (final entry in usage.hourlyCategorySeconds.entries) entry.key: Map.of(entry.value),
    };
    _reminders = List.of(usage.reminders);
  }

  DailyUsage _buildSnapshotUsage() => DailyUsage(
    date: _date,
    totalActiveSeconds: _totalActiveSeconds,
    continuousActiveSeconds: _continuousActiveSeconds,
    apps: Map.of(_apps),
    hourlyCategorySeconds: {for (final entry in _hourlyCategorySeconds.entries) entry.key: Map.of(entry.value)},
    reminders: List.of(_reminders),
  );

  Future<void> _onTick() async {
    if (_isTicking) return;
    _isTicking = true;
    try {
      await tick();
    } finally {
      _isTicking = false;
    }
  }

  /// Runs one tick of the tracking loop. Called every second by the
  /// internal timer once [start] is running; exposed publicly so tests
  /// can drive it directly without waiting on a real timer.
  Future<void> tick() async {
    final now = _now();

    if (dateOnly(now) != _date) {
      await _save();
      _loadWorkingState(await _usageRepository.load(dateOnly(now)));
      _lastAppId = null;
      _wasActive = false;
      _nextSaveAt = _alignToNextFiveMinute(now);
    }

    final idleTime = _idleDetector.idleTime();
    var isActive = idleTime < Duration(seconds: _settings.idleThresholdSeconds);
    var currentApp = isActive ? _foregroundReader.current() : null;

    if (_isPaused) {
      isActive = false;
      currentApp = null;
    }

    if (currentApp != null) {
      _accumulate(currentApp, now);
    } else if (_wasActive) {
      // Active -> idle transition: back out the trailing seconds that were
      // counted as active before the idle threshold actually tripped.
      _rewindIdleTail();
      _lastAppId = null;
    }

    _wasActive = isActive;

    var shouldSave = false;
    if (!now.isBefore(_nextSaveAt)) {
      shouldSave = true;
      _nextSaveAt = _alignToNextFiveMinute(now);
    }

    _snapshotController.add(
      UsageSnapshot(
        todayUsage: _buildSnapshotUsage(),
        currentApp: currentApp,
        isActive: isActive,
        isPaused: _isPaused,
        idleTime: idleTime,
        updatedAt: now,
      ),
    );

    if (shouldSave) await _save();
  }

  void _accumulate(ForegroundApp app, DateTime now) {
    final appId = app.appId;
    final category = _classifier.classify(app);
    final existing = _apps[appId];
    final baseline =
        existing ??
        AppUsage(
          name: app.name,
          processName: app.processName,
          executablePath: app.executablePath,
          category: category,
          activeSeconds: 0,
          firstUsedAt: now,
          lastUsedAt: now,
        );

    _apps[appId] = baseline.copyWith(
      name: app.name,
      processName: app.processName,
      executablePath: app.executablePath,
      category: category,
      activeSeconds: baseline.activeSeconds + 1,
      lastUsedAt: now,
    );

    _totalActiveSeconds++;
    _continuousActiveSeconds++;
    _addHourlyCategorySecond(now.hour, category);

    _lastAppId = appId;
    _lastActiveCategory = category;
  }

  void _addHourlyCategorySecond(int hour, AppCategory category) {
    final bucket = _hourlyCategorySeconds.putIfAbsent(hour, () => {});
    bucket[category] = (bucket[category] ?? 0) + 1;
  }

  /// Corrects the trailing over-count created because an active->idle
  /// transition is only detected once the idle threshold has fully
  /// elapsed: those elapsed seconds were counted as active up until the
  /// threshold tripped, so they must be subtracted back out now. Skipping
  /// this produces totals inflated by roughly the idle threshold on every
  /// active->idle transition. Functional spec section 1.
  void _rewindIdleTail() {
    final appId = _lastAppId;
    if (appId == null) return;
    final usage = _apps[appId];
    if (usage == null) return;

    final rewindSeconds = [
      _settings.idleThresholdSeconds,
      usage.activeSeconds,
      _totalActiveSeconds,
      _continuousActiveSeconds,
    ].reduce((a, b) => a < b ? a : b);
    if (rewindSeconds <= 0) return;

    final rewoundLastUsedAt = usage.lastUsedAt.subtract(Duration(seconds: rewindSeconds));
    _apps[appId] = usage.copyWith(
      activeSeconds: usage.activeSeconds - rewindSeconds,
      lastUsedAt: rewoundLastUsedAt.isBefore(usage.firstUsedAt) ? usage.firstUsedAt : rewoundLastUsedAt,
    );
    _totalActiveSeconds -= rewindSeconds;
    _continuousActiveSeconds -= rewindSeconds;
    _removeHourlyCategorySeconds(_now(), rewindSeconds, _lastActiveCategory);
  }

  /// Walks backward hour-by-hour from [from], subtracting up to [seconds]
  /// total from [category]'s bucket in each hour (never below zero),
  /// mirroring how the seconds were originally added tick-by-tick.
  void _removeHourlyCategorySeconds(DateTime from, int seconds, AppCategory category) {
    var remaining = seconds;
    var cursor = from;
    final cutoff = from.subtract(const Duration(hours: 24));

    while (remaining > 0 && cursor.isAfter(cutoff)) {
      final bucket = _hourlyCategorySeconds[cursor.hour];
      final available = bucket?[category] ?? 0;
      final take = available < remaining ? available : remaining;
      if (bucket != null && take > 0) {
        final newValue = available - take;
        if (newValue <= 0) {
          bucket.remove(category);
        } else {
          bucket[category] = newValue;
        }
        if (bucket.isEmpty) _hourlyCategorySeconds.remove(cursor.hour);
      }
      remaining -= take;
      cursor = cursor.subtract(const Duration(hours: 1));
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _usageRepository.save(_buildSnapshotUsage());
    } finally {
      _isSaving = false;
    }
  }

  /// Rounds [from] up to the next wall-clock 5-minute boundary (00, 05,
  /// 10, ...), always strictly in the future.
  DateTime _alignToNextFiveMinute(DateTime from) {
    final flooredMinute = (from.minute ~/ 5) * 5;
    return DateTime(from.year, from.month, from.day, from.hour, flooredMinute).add(const Duration(minutes: 5));
  }
}
