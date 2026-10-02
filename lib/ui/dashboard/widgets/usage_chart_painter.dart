import 'package:flutter/material.dart';

import '../../../domain/models/app_category.dart';
import '../../../theme/app_colors.dart';
import '../view_models/dashboard_view_model.dart' show ChartBucket;

const _categoryPaintOrder = [
  AppCategory.work,
  AppCategory.social,
  AppCategory.entertainment,
  AppCategory.learning,
  AppCategory.system,
  AppCategory.other,
];

/// Draws a stacked bar per [ChartBucket], scaled against [axisMaxSeconds],
/// plus an optional dashed average line. Purely a renderer — tap
/// detection lives in the parent widget (usage_chart.dart) so this stays
/// a simple, stateless painter.
class UsageChartPainter extends CustomPainter {
  UsageChartPainter({required this.buckets, required this.axisMaxSeconds, this.averageSeconds, this.highlightedIndex});

  final List<ChartBucket> buckets;
  final int axisMaxSeconds;
  final int? averageSeconds;
  final int? highlightedIndex;

  static const _gapFraction = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty || axisMaxSeconds <= 0) return;

    final columnWidth = size.width / buckets.length;
    final barWidth = columnWidth * (1 - _gapFraction);

    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final columnLeft = i * columnWidth + (columnWidth - barWidth) / 2;
      var yCursor = size.height;
      final isDimmed = highlightedIndex != null && highlightedIndex != i;

      for (final category in _categoryPaintOrder) {
        final seconds = bucket.secondsByCategory[category];
        if (seconds == null || seconds <= 0) continue;
        final segmentHeight = size.height * (seconds / axisMaxSeconds);
        final rect = Rect.fromLTWH(columnLeft, yCursor - segmentHeight, barWidth, segmentHeight);
        final paint = Paint()
          ..color = (categoryColors[category] ?? Colors.grey).withValues(alpha: isDimmed ? 0.35 : 1);
        canvas.drawRect(rect, paint);
        yCursor -= segmentHeight;
      }
    }

    final average = averageSeconds;
    if (average != null && average > 0) {
      final y = size.height * (1 - average / axisMaxSeconds);
      final linePaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.8)
        ..strokeWidth = 1;
      const dashWidth = 4.0;
      const dashGap = 3.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), linePaint);
        x += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant UsageChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.axisMaxSeconds != axisMaxSeconds ||
        oldDelegate.averageSeconds != averageSeconds ||
        oldDelegate.highlightedIndex != highlightedIndex;
  }
}
