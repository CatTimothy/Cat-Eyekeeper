import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_category.dart';

part 'category_rule.freezed.dart';
part 'category_rule.g.dart';

/// A weighted keyword-matching rule for one [AppCategory]. See
/// core/category_classifier.dart for how the weights are applied.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class CategoryRule with _$CategoryRule {
  const CategoryRule._();

  const factory CategoryRule({
    @JsonKey(fromJson: appCategoryFromJson, toJson: appCategoryToJson) required AppCategory category,
    @Default([]) List<String> processNames,
    @Default([]) List<String> pathKeywords,
    @Default([]) List<String> nameKeywords,
    @Default([]) List<String> windowTitleKeywords,
  }) = _CategoryRule;

  factory CategoryRule.fromJson(Map<String, dynamic> json) => _$CategoryRuleFromJson(json);

  /// Additively merges [other]'s keyword lists into this rule: any keyword
  /// (case-insensitive) not already present is appended. Used by
  /// CategoryRuleRepository to upgrade a user's saved rule set with new
  /// built-in keywords without discarding their customizations.
  CategoryRule mergedWith(CategoryRule other) {
    assert(category == other.category);
    return CategoryRule(
      category: category,
      processNames: _mergeKeywords(processNames, other.processNames),
      pathKeywords: _mergeKeywords(pathKeywords, other.pathKeywords),
      nameKeywords: _mergeKeywords(nameKeywords, other.nameKeywords),
      windowTitleKeywords: _mergeKeywords(windowTitleKeywords, other.windowTitleKeywords),
    );
  }
}

List<String> _mergeKeywords(List<String> existing, List<String> incoming) {
  final merged = [...existing];
  for (final keyword in incoming) {
    final alreadyPresent = merged.any((e) => e.toLowerCase() == keyword.toLowerCase());
    if (!alreadyPresent) merged.add(keyword);
  }
  return merged;
}

/// A versioned collection of [CategoryRule]s. `version` drives the
/// merge-upgrade logic in CategoryRuleRepository.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class CategoryRules with _$CategoryRules {
  const CategoryRules._();

  const factory CategoryRules({required int version, required List<CategoryRule> rules}) = _CategoryRules;

  factory CategoryRules.fromJson(Map<String, dynamic> json) => _$CategoryRulesFromJson(json);

  /// Built-in seed rules covering common desktop-app scenarios. Bump
  /// [version] whenever keywords are added here; CategoryRuleRepository
  /// merges new keywords into a user's saved rules rather than overwriting.
  ///
  /// A `static` method rather than a named factory constructor — freezed's
  /// code generator only special-cases named `factory` redirects (used for
  /// union types), and this is a plain helper, not another constructor.
  static CategoryRules defaults() => const CategoryRules(
    version: 1,
    rules: [
      CategoryRule(
        category: AppCategory.work,
        processNames: [
          'code', 'devenv', 'idea64', 'pycharm64', 'webstorm64', 'clion64', 'rider64',
          'sublime_text', 'windowsterminal', 'cmd', 'powershell', 'pwsh', 'git', 'docker',
          'excel', 'winword', 'powerpnt', 'outlook', 'notion', 'figma', 'postman',
        ],
        pathKeywords: ['jetbrains', 'microsoft office', 'visual studio'],
        nameKeywords: [
          'Visual Studio Code', 'Visual Studio', 'IntelliJ', 'PyCharm', 'WebStorm', 'Excel',
          'Word', 'PowerPoint', 'Outlook', 'Notion', 'Figma', 'Postman', 'Docker Desktop',
        ],
        windowTitleKeywords: ['Visual Studio Code', '- Excel', '- Word', '- PowerPoint'],
      ),
      CategoryRule(
        category: AppCategory.social,
        processNames: [
          'wechat', 'weixin', 'qq', 'dingtalk', 'slack', 'discord', 'telegram', 'whatsapp',
          'line', 'teams', 'skype', 'zoom', 'feishu', 'lark',
        ],
        nameKeywords: [
          'WeChat', '微信', 'QQ', 'DingTalk', '钉钉', 'Slack', 'Discord', 'Telegram', 'WhatsApp',
          'LINE', 'Microsoft Teams', 'Skype', 'Zoom', '飞书', 'Lark',
        ],
        windowTitleKeywords: ['微信', 'Zoom Meeting'],
      ),
      CategoryRule(
        category: AppCategory.entertainment,
        processNames: [
          'steam', 'epicgameslauncher', 'vlc', 'mpv', 'potplayer', 'iina', 'spotify',
          'bilibili', 'douyin', 'wegame',
        ],
        nameKeywords: [
          'Steam', 'Epic Games', 'VLC', 'PotPlayer', 'Spotify', 'Netflix', 'Bilibili', '哔哩哔哩',
          '抖音', 'TikTok', 'GOG Galaxy',
        ],
        windowTitleKeywords: ['YouTube', 'Netflix', 'Bilibili', '哔哩哔哩', 'Twitch', 'Steam'],
      ),
      CategoryRule(
        category: AppCategory.learning,
        processNames: ['anki', 'obsidian', 'zotero', 'marginnote', 'goodnotes'],
        nameKeywords: ['Anki', 'Obsidian', 'Zotero', 'Kindle', 'Duolingo', '有道词典', 'MarginNote', 'GoodNotes'],
        windowTitleKeywords: ['Coursera', 'Udemy', '中国大学MOOC', '学习通'],
      ),
      CategoryRule(
        category: AppCategory.system,
        processNames: [
          'explorer', 'dwm', 'taskmgr', 'systemsettings', 'controlpanel', 'svchost', 'wininit',
          'csrss', 'lsass', 'services', 'conhost', 'searchapp', 'searchhost', 'textinputhost',
          'shellexperiencehost', 'applicationframehost',
        ],
        nameKeywords: ['Windows Explorer', 'Task Manager', 'Settings', 'Control Panel', '文件管理器', '设置', '系统'],
      ),
    ],
  );
}
