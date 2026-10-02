import 'dart:convert';
import 'dart:io';

import '../../domain/models/daily_usage.dart';
import '../../domain/models/date_stamp.dart';
import 'app_paths.dart';
import 'atomic_writer.dart';
import 'json_codec.dart';

/// Loads/saves one JSON file per calendar day under `usage/`.
class UsageRepository {
  UsageRepository({required this.paths, AtomicWriter? writer}) : _writer = writer ?? const AtomicWriter();

  final AppPaths paths;
  final AtomicWriter _writer;

  Future<DailyUsage> loadToday() => load(dateOnly(DateTime.now()));

  /// Loads the record for [date], creating and persisting an empty one if
  /// none exists yet.
  Future<DailyUsage> load(DateTime date) async {
    await paths.ensureCreated();
    final file = File(paths.usageFile(date));
    if (!await file.exists()) {
      final empty = DailyUsage(date: dateOnly(date));
      await save(empty);
      return empty;
    }
    try {
      final raw = await file.readAsString();
      return DailyUsage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return _resetToEmpty(file, date);
    } on TypeError {
      // Valid JSON but the wrong shape — treat the same as corrupt.
      return _resetToEmpty(file, date);
    }
  }

  Future<DailyUsage> _resetToEmpty(File file, DateTime date) async {
    await backupCorruptFile(file);
    final empty = DailyUsage(date: dateOnly(date));
    await save(empty);
    return empty;
  }

  /// Read-only variant for historical lookups (e.g. browsing past days in
  /// the dashboard): never creates a file and never writes a `.corrupt`
  /// backup on a parse failure, just returns an in-memory empty record.
  Future<DailyUsage> loadExistingOrEmpty(DateTime date) async {
    final file = File(paths.usageFile(date));
    if (!await file.exists()) return DailyUsage(date: dateOnly(date));
    try {
      final raw = await file.readAsString();
      return DailyUsage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return DailyUsage(date: dateOnly(date));
    } on TypeError {
      return DailyUsage(date: dateOnly(date));
    }
  }

  Future<void> save(DailyUsage usage) async {
    await paths.ensureCreated();
    await _writer.writeString(paths.usageFile(usage.date), encodePretty(usage.toJson()));
  }

  /// Deletes every persisted daily usage file (Settings' "clear data"
  /// action) without deleting the `usage/` directory itself. Irreversible
  /// — callers must confirm with the user first.
  Future<void> clearAll() async {
    final dir = Directory(paths.usageDirectory);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
  }
}
