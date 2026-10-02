import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/responsive.dart';
import '../view_models/dashboard_view_model.dart';
import 'app_usage_tile.dart';

/// The per-app usage table (functional spec section 5): icon, name +
/// progress bar, category, time, weekly daily-average, share — sorted by
/// usage descending, filterable by the category legend. Drops the
/// category/daily-average columns below [kCompactWidthBreakpoint] — see
/// AppUsageTile's `compact` param. Reads straight from [viewModel] — no
/// Riverpod here, see ui/dashboard/widgets/usage_chart.dart's doc comment.
class AppUsageList extends StatelessWidget {
  const AppUsageList({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final list = viewModel.appUsageList;
    final compact = isCompactWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dashboardAppListHeader, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _ColumnHeaders(l10n: l10n, compact: compact),
        const Divider(height: 16),
        Expanded(
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
              ? Center(child: Text(l10n.dashboardEmptyState, style: theme.textTheme.bodyMedium))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      AppUsageTile(summary: list[index], compact: compact, viewModel: viewModel),
                ),
        ),
      ],
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.l10n, required this.compact});

  final AppLocalizations l10n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(
      children: [
        const SizedBox(width: 40), // aligns with the icon column
        Expanded(flex: 3, child: Text(l10n.dashboardColumnApp, style: style)),
        if (!compact) Expanded(child: Text(l10n.dashboardColumnCategory, style: style)),
        Expanded(child: Text(l10n.dashboardColumnTime, style: style)),
        if (!compact) Expanded(child: Text(l10n.dashboardColumnDailyAverage, style: style)),
        Expanded(child: Text(l10n.dashboardColumnShare, style: style)),
      ],
    );
  }
}
