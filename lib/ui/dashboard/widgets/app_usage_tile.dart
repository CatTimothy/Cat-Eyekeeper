import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../core/format.dart';
import '../view_models/dashboard_view_model.dart';
import 'category_legend.dart';

class AppUsageTile extends StatelessWidget {
  const AppUsageTile({super.key, required this.summary, required this.viewModel, this.compact = false});

  final AppUsageSummary summary;
  final DashboardViewModel viewModel;

  /// Hides the category and daily-average columns — see
  /// ui/dashboard/widgets/app_usage_list.dart's `_ColumnHeaders`, which
  /// hides the matching header labels. Below phone width there isn't
  /// room for all 5 columns to stay legible, so this keeps only what
  /// matters most: name, total time, and share.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final color = categoryColors[summary.category] ?? theme.colorScheme.outline;
    final iconBytes = viewModel.appIconFor(summary.appId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _AppIcon(name: summary.name, color: color, iconBytes: iconBytes),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.name, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.shareOfTotal.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          if (!compact) Expanded(child: Text(categoryLabel(l10n, summary.category), overflow: TextOverflow.ellipsis)),
          Expanded(child: Text(formatDurationShort(Duration(seconds: summary.totalSeconds)), overflow: TextOverflow.ellipsis)),
          if (!compact)
            Expanded(
              child: Text(formatDurationShort(Duration(seconds: summary.dailyAverageSeconds)), overflow: TextOverflow.ellipsis),
            ),
          Expanded(child: Text('${(summary.shareOfTotal * 100).toStringAsFixed(0)}%', overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.name, required this.color, required this.iconBytes});

  final String name;
  final Color color;

  /// The app's real icon, or null to fall back to a letter avatar (no
  /// icon resource found, protected/sandboxed process, or Linux — see
  /// platform/app_icon_reader.dart).
  final Uint8List? iconBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = iconBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, width: 28, height: 28, gaplessPlayback: true),
      );
    }

    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
