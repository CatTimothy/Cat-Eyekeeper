import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../l10n/app_localizations.dart';
import '../../core/format.dart';
import '../view_models/dashboard_view_model.dart';
import 'usage_chart_painter.dart';

/// Daily/weekly toggle, period navigation, and the stacked bar chart
/// itself (functional spec section 5). Reads straight from [viewModel] —
/// no Riverpod here; the owning ui/dashboard/dashboard_screen.dart already
/// wraps this whole subtree in a `ListenableBuilder` over the same
/// instance, so this widget just rebuilds along with it.
class UsageChart extends StatefulWidget {
  const UsageChart({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  State<UsageChart> createState() => _UsageChartState();
}

class _UsageChartState extends State<UsageChart> {
  int? _highlightedIndex;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  void _onBarTap(int index) {
    setState(() => _highlightedIndex = index);
    _revertTimer?.cancel();
    _revertTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _highlightedIndex = null);
    });
  }

  void _clearHighlight() {
    _revertTimer?.cancel();
    if (_highlightedIndex != null) setState(() => _highlightedIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = widget.viewModel;
    final period = viewModel.period;
    final chart = viewModel.chartData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SegmentedButton<ChartViewMode>(
              segments: [
                ButtonSegment(value: ChartViewMode.daily, label: Text(l10n.dashboardDailyView)),
                ButtonSegment(value: ChartViewMode.weekly, label: Text(l10n.dashboardWeeklyView)),
              ],
              selected: {period.mode},
              onSelectionChanged: (selection) {
                viewModel.setPeriodMode(selection.first);
                _clearHighlight();
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                viewModel.goToPreviousPeriod();
                _clearHighlight();
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: viewModel.canGoNext
                  ? () {
                      viewModel.goToNextPeriod();
                      _clearHighlight();
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (chart == null)
          const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
        else
          _buildChart(context, l10n, chart, period),
      ],
    );
  }

  Widget _buildChart(BuildContext context, AppLocalizations l10n, ChartData chart, DashboardPeriod period) {
    final theme = Theme.of(context);
    final highlightedBucket =
        (_highlightedIndex != null && _highlightedIndex! < chart.buckets.length) ? chart.buckets[_highlightedIndex!] : null;
    final totalSeconds = highlightedBucket?.totalSeconds ?? chart.totalSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dashboardPeriodTotal(formatDurationShort(Duration(seconds: totalSeconds))), style: theme.textTheme.headlineSmall),
        if (chart.averageSeconds != null)
          Text(
            l10n.dashboardWeeklyAverage(formatDurationShort(Duration(seconds: chart.averageSeconds!))),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (chart.buckets.isEmpty) return;
                  final columnWidth = constraints.maxWidth / chart.buckets.length;
                  final index = (details.localPosition.dx / columnWidth).floor().clamp(0, chart.buckets.length - 1);
                  _onBarTap(index);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: UsageChartPainter(
                    buckets: chart.buckets,
                    axisMaxSeconds: chart.axisMaxSeconds,
                    averageSeconds: chart.averageSeconds,
                    highlightedIndex: _highlightedIndex,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _AxisLabels(mode: period.mode, count: chart.buckets.length),
      ],
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.mode, required this.count});

  final ChartViewMode mode;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    if (mode == ChartViewMode.daily) {
      return Row(
        children: List.generate(24, (hour) {
          final label = hour % 6 == 0 ? '$hour' : '';
          return Expanded(child: Center(child: Text(label, style: style)));
        }),
      );
    }

    final weekdayFormat = intl.DateFormat.E(Localizations.localeOf(context).toLanguageTag());
    final aKnownMonday = DateTime(2024, 1, 1);
    return Row(
      children: List.generate(count, (i) {
        final label = weekdayFormat.format(aKnownMonday.add(Duration(days: i)));
        return Expanded(child: Center(child: Text(label, style: style)));
      }),
    );
  }
}
