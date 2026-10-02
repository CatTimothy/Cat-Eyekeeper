/// The six buckets every tracked application is classified into.
enum AppCategory { work, social, entertainment, learning, system, other }

const Map<AppCategory, String> _appCategoryJsonValues = {
  AppCategory.work: 'work',
  AppCategory.social: 'social',
  AppCategory.entertainment: 'entertainment',
  AppCategory.learning: 'learning',
  AppCategory.system: 'system',
  AppCategory.other: 'other',
};

String appCategoryToJson(AppCategory category) => _appCategoryJsonValues[category]!;

AppCategory appCategoryFromJson(String value) => _appCategoryJsonValues.entries
    .firstWhere((entry) => entry.value == value, orElse: () => const MapEntry(AppCategory.other, 'other'))
    .key;
