import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/repositories/app_paths.dart';
import 'package:cat_eyekeeper/data/repositories/usage_repository.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';

void main() {
  late Directory tempDir;
  late UsageRepository repository;
  late AppPaths paths;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('usage_repo_test_');
    paths = AppPaths(overrideBaseDirectory: tempDir.path);
    repository = UsageRepository(paths: paths);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('load() for a new date creates and persists an empty record', () async {
    final date = DateTime(2026, 7, 15);
    final loaded = await repository.load(date);

    expect(loaded.date, date);
    expect(loaded.totalActiveSeconds, 0);
    expect(File(paths.usageFile(date)).existsSync(), isTrue);
  });

  test('save() then load() round-trips totals', () async {
    final date = DateTime(2026, 7, 15);
    await repository.save(DailyUsage(date: date, totalActiveSeconds: 500));

    final loaded = await repository.load(date);

    expect(loaded.totalActiveSeconds, 500);
  });

  test('loadExistingOrEmpty() does not create a file for a missing date', () async {
    final date = DateTime(2020, 1, 1);
    final loaded = await repository.loadExistingOrEmpty(date);

    expect(loaded.totalActiveSeconds, 0);
    expect(File(paths.usageFile(date)).existsSync(), isFalse);
  });

  test('a corrupt day file is backed up and replaced with an empty record', () async {
    final date = DateTime(2026, 7, 15);
    final file = File(paths.usageFile(date));
    await file.create(recursive: true);
    await file.writeAsString('{not valid json');

    final loaded = await repository.load(date);

    expect(loaded.totalActiveSeconds, 0);
    expect(File('${file.path}.corrupt').existsSync(), isTrue);
  });

  test('clearAll() deletes every persisted day file but keeps the directory', () async {
    await repository.save(DailyUsage(date: DateTime(2026, 7, 14), totalActiveSeconds: 100));
    await repository.save(DailyUsage(date: DateTime(2026, 7, 15), totalActiveSeconds: 200));

    await repository.clearAll();

    expect(File(paths.usageFile(DateTime(2026, 7, 14))).existsSync(), isFalse);
    expect(File(paths.usageFile(DateTime(2026, 7, 15))).existsSync(), isFalse);
    expect(Directory(paths.usageDirectory).existsSync(), isTrue);
  });

  test('clearAll() on a missing directory does not throw', () async {
    await expectLater(repository.clearAll(), completes);
  });
}
