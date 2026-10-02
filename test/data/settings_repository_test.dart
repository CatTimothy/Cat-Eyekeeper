import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/repositories/app_paths.dart';
import 'package:cat_eyekeeper/data/repositories/settings_repository.dart';
import 'package:cat_eyekeeper/domain/models/settings.dart';

void main() {
  late Directory tempDir;
  late SettingsRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('settings_repo_test_');
    repository = SettingsRepository(paths: AppPaths(overrideBaseDirectory: tempDir.path));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('load() creates and persists defaults when no file exists', () async {
    final loaded = await repository.load();

    expect(loaded.reminderIntervalMinutes, Settings.defaults().reminderIntervalMinutes);
    expect(File('${tempDir.path}/settings.json').existsSync(), isTrue);
  });

  test('save() then load() round-trips a modified value', () async {
    await repository.save(Settings.defaults().copyWith(reminderIntervalMinutes: 20));

    final loaded = await repository.load();

    expect(loaded.reminderIntervalMinutes, 20);
  });

  test('backs up a corrupt settings file and resets to defaults', () async {
    final file = File('${tempDir.path}/settings.json');
    await file.create(recursive: true);
    await file.writeAsString('{not valid json');

    final loaded = await repository.load();

    expect(loaded.reminderIntervalMinutes, Settings.defaults().reminderIntervalMinutes);
    expect(File('${tempDir.path}/settings.json.corrupt').existsSync(), isTrue);
  });

  test('valid JSON with the wrong shape is treated as corrupt, not a crash', () async {
    // e.g. an unrelated app's settings file that happens to share a
    // directory name — syntactically valid JSON, but missing every field
    // this app expects.
    final file = File('${tempDir.path}/settings.json');
    await file.create(recursive: true);
    await file.writeAsString('{"some_other_apps_field": true}');

    final loaded = await repository.load();

    expect(loaded.reminderIntervalMinutes, Settings.defaults().reminderIntervalMinutes);
    expect(File('${tempDir.path}/settings.json.corrupt').existsSync(), isTrue);
  });
}
