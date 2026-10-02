import 'dart:convert';
import 'dart:io';

import '../../domain/models/app_category.dart';
import '../../domain/models/category_rule.dart';
import 'app_paths.dart';
import 'atomic_writer.dart';
import 'json_codec.dart';

/// Loads/saves the [CategoryRules] file. When the built-in default ruleset's
/// version is newer than what's saved on disk, new keywords are merged into
/// the user's existing rules (never overwritten) and the result is re-saved
/// — see [CategoryRule.mergedWith].
class CategoryRuleRepository {
  CategoryRuleRepository({required this.paths, AtomicWriter? writer}) : _writer = writer ?? const AtomicWriter();

  final AppPaths paths;
  final AtomicWriter _writer;

  Future<CategoryRules> load() async {
    await paths.ensureCreated();
    final file = File(paths.categoryRulesFile);
    final defaults = CategoryRules.defaults();
    if (!await file.exists()) {
      await save(defaults);
      return defaults;
    }
    try {
      final raw = await file.readAsString();
      var loaded = CategoryRules.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (loaded.version < defaults.version) {
        loaded = _upgrade(loaded, defaults);
        await save(loaded);
      }
      return loaded;
    } on FormatException {
      return _resetToDefaults(file, defaults);
    } on TypeError {
      // Valid JSON but the wrong shape — treat the same as corrupt.
      return _resetToDefaults(file, defaults);
    }
  }

  Future<CategoryRules> _resetToDefaults(File file, CategoryRules defaults) async {
    await backupCorruptFile(file);
    await save(defaults);
    return defaults;
  }

  Future<void> save(CategoryRules rules) async {
    await paths.ensureCreated();
    await _writer.writeString(paths.categoryRulesFile, encodePretty(rules.toJson()));
  }

  CategoryRules _upgrade(CategoryRules loaded, CategoryRules defaults) {
    final merged = <AppCategory, CategoryRule>{for (final rule in loaded.rules) rule.category: rule};
    for (final defaultRule in defaults.rules) {
      final existing = merged[defaultRule.category];
      merged[defaultRule.category] = existing == null ? defaultRule : existing.mergedWith(defaultRule);
    }
    return CategoryRules(version: defaults.version, rules: merged.values.toList());
  }
}
