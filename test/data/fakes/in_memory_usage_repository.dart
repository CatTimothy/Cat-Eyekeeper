import 'package:cat_eyekeeper/data/repositories/app_paths.dart';
import 'package:cat_eyekeeper/data/repositories/usage_repository.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';
import 'package:cat_eyekeeper/domain/models/date_stamp.dart';

/// An in-memory stand-in for [UsageRepository] so TrackingEngine tests
/// don't touch the filesystem. Keyed by date stamp, same identity rule
/// the real repository uses for its one-file-per-day layout.
class InMemoryUsageRepository implements UsageRepository {
  // Never actually read from disk here (every method below is overridden
  // to use the in-memory map instead) — this just satisfies the
  // interface's `paths` getter.
  @override
  final AppPaths paths = AppPaths(overrideBaseDirectory: 'unused');

  final Map<String, DailyUsage> _byDate = {};
  int saveCount = 0;

  @override
  Future<DailyUsage> loadToday() => load(dateOnly(DateTime.now()));

  @override
  Future<DailyUsage> load(DateTime date) async {
    final key = formatDateStamp(date);
    return _byDate[key] ?? DailyUsage(date: dateOnly(date));
  }

  @override
  Future<DailyUsage> loadExistingOrEmpty(DateTime date) => load(date);

  @override
  Future<void> save(DailyUsage usage) async {
    saveCount++;
    _byDate[formatDateStamp(usage.date)] = usage;
  }

  @override
  Future<void> clearAll() async {
    _byDate.clear();
  }
}
