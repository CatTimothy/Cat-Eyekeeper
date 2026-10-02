import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/models/app_category.dart';
import '../../../theme/app_colors.dart';
import '../../core/format.dart';

const _categoryOrder = [
  AppCategory.work,
  AppCategory.social,
  AppCategory.entertainment,
  AppCategory.learning,
  AppCategory.system,
  AppCategory.other,
];

String categoryLabel(AppLocalizations l10n, AppCategory category) {
  switch (category) {
    case AppCategory.work:
      return l10n.categoryWork;
    case AppCategory.social:
      return l10n.categorySocial;
    case AppCategory.entertainment:
      return l10n.categoryEntertainment;
    case AppCategory.learning:
      return l10n.categoryLearning;
    case AppCategory.system:
      return l10n.categorySystem;
    case AppCategory.other:
      return l10n.categoryOther;
  }
}

/// Clickable chips for every category with nonzero time in the current
/// period; clicking filters the app usage list, clicking the active one
/// again clears the filter (functional spec section 5).
class CategoryLegend extends StatelessWidget {
  const CategoryLegend({
    super.key,
    required this.totalsByCategory,
    required this.selected,
    required this.onSelect,
  });

  final Map<AppCategory, int> totalsByCategory;
  final AppCategory? selected;
  final ValueChanged<AppCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _categoryOrder.where((c) => (totalsByCategory[c] ?? 0) > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: visible.map((category) {
        final isSelected = selected == category;
        final color = categoryColors[category]!;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onSelect(category),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
              border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${categoryLabel(l10n, category)} · ${formatDurationShort(Duration(seconds: totalsByCategory[category]!))}'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
