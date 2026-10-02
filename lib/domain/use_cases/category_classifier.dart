import '../models/app_category.dart';
import '../models/category_rule.dart';
import '../models/foreground_app.dart';

/// Scores an app against every [CategoryRule] and picks the
/// highest-scoring category (functional spec section 2's weights):
/// exact process name +100, path keyword +70, name keyword +50, window
/// title keyword +45. Defaults to [AppCategory.other] when nothing matches.
class CategoryClassifier {
  const CategoryClassifier(this.rules);

  final CategoryRules rules;

  AppCategory classify(ForegroundApp app) {
    var best = AppCategory.other;
    var bestScore = 0;

    for (final rule in rules.rules) {
      var score = 0;
      if (_matchesExact(app.processName, rule.processNames)) score += 100;
      if (_containsAny(app.executablePath, rule.pathKeywords)) score += 70;
      if (_containsAny(app.name, rule.nameKeywords)) score += 50;
      if (_containsAny(app.windowTitle, rule.windowTitleKeywords)) score += 45;

      if (score > bestScore) {
        bestScore = score;
        best = rule.category;
      }
    }
    return best;
  }

  bool _matchesExact(String value, List<String> candidates) {
    if (value.trim().isEmpty) return false;
    return candidates.any((candidate) => candidate.toLowerCase() == value.toLowerCase());
  }

  bool _containsAny(String value, List<String> keywords) {
    if (value.trim().isEmpty) return false;
    final lower = value.toLowerCase();
    return keywords.any((keyword) => lower.contains(keyword.toLowerCase()));
  }
}
