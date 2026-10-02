import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/models/app_category.dart';
import 'package:cat_eyekeeper/domain/models/category_rule.dart';

void main() {
  test('mergedWith adds new keywords without duplicating or dropping existing ones', () {
    const userCustomized = CategoryRule(
      category: AppCategory.work,
      processNames: ['mycustomtool'],
      nameKeywords: ['My Custom Tool'],
    );
    const updatedDefaults = CategoryRule(
      category: AppCategory.work,
      processNames: ['code', 'MYCUSTOMTOOL'], // case-insensitive duplicate of the user's entry
      nameKeywords: ['Visual Studio Code'],
    );

    final merged = userCustomized.mergedWith(updatedDefaults);

    expect(merged.processNames, ['mycustomtool', 'code']);
    expect(merged.nameKeywords, ['My Custom Tool', 'Visual Studio Code']);
  });

  test('CategoryRules.defaults() covers all non-other categories with at least one rule', () {
    final defaults = CategoryRules.defaults();
    final coveredCategories = defaults.rules.map((r) => r.category).toSet();

    for (final category in AppCategory.values) {
      if (category == AppCategory.other) continue;
      expect(coveredCategories, contains(category), reason: '$category should have a seed rule');
    }
  });

  test('CategoryRules round-trips through JSON', () {
    final original = CategoryRules.defaults();
    final decoded = CategoryRules.fromJson(original.toJson());

    expect(decoded.version, original.version);
    expect(decoded.rules.length, original.rules.length);
  });
}
