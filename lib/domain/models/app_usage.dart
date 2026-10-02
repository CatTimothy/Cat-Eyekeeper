import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_category.dart';

part 'app_usage.freezed.dart';
part 'app_usage.g.dart';

/// Accumulated usage for a single application on a single day.
@freezed
abstract class AppUsage with _$AppUsage {
  const factory AppUsage({
    required String name,
    required String processName,
    required String executablePath,
    @JsonKey(fromJson: appCategoryFromJson, toJson: appCategoryToJson) required AppCategory category,
    required int activeSeconds,
    required DateTime firstUsedAt,
    required DateTime lastUsedAt,
  }) = _AppUsage;

  factory AppUsage.fromJson(Map<String, dynamic> json) => _$AppUsageFromJson(json);
}
