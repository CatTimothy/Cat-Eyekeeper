import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/repositories/app_paths.dart';
import 'package:cat_eyekeeper/data/repositories/category_rule_repository.dart';
import 'package:cat_eyekeeper/domain/models/app_category.dart';
import 'package:cat_eyekeeper/domain/models/category_rule.dart';

void main() {
  late Directory tempDir;
  late CategoryRuleRepository repository;
  late AppPaths paths;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('category_rule_repo_test_');
    paths = AppPaths(overrideBaseDirectory: tempDir.path);
    repository = CategoryRuleRepository(paths: paths);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('load() creates and persists the built-in defaults when no file exists', () async {
    final loaded = await repository.load();

    expect(loaded.version, CategoryRules.defaults().version);
    expect(File(paths.categoryRulesFile).existsSync(), isTrue);
  });

  test('an older saved version is merge-upgraded: user keywords survive, new ones are added', () async {
    // Simulate a user who customized the Work rule on an older ruleset
    // version, then a newer app version ships an updated default ruleset.
    const staleUserRules = CategoryRules(
      version: 0,
      rules: [
        CategoryRule(category: AppCategory.work, processNames: ['mycustomtool']),
      ],
    );
    await File(
      paths.categoryRulesFile,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(staleUserRules.toJson()));

    final upgraded = await repository.load();
    final workRule = upgraded.rules.firstWhere((r) => r.category == AppCategory.work);

    expect(upgraded.version, CategoryRules.defaults().version);
    expect(workRule.processNames, contains('mycustomtool')); // user customization preserved
    expect(workRule.processNames, contains('code')); // new built-in keyword merged in
  });

  test('a category missing entirely from the saved file is filled in from defaults', () async {
    const staleUserRules = CategoryRules(version: 0, rules: []);
    await File(
      paths.categoryRulesFile,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(staleUserRules.toJson()));

    final upgraded = await repository.load();

    expect(upgraded.rules.map((r) => r.category), containsAll(CategoryRules.defaults().rules.map((r) => r.category)));
  });

  test('backs up a corrupt category rules file and resets to defaults', () async {
    final file = File(paths.categoryRulesFile);
    await file.create(recursive: true);
    await file.writeAsString('{not valid json');

    final loaded = await repository.load();

    expect(loaded.version, CategoryRules.defaults().version);
    expect(File('${file.path}.corrupt').existsSync(), isTrue);
  });
}
