import 'package:flutter/material.dart';

import '../../core/format.dart';

class CountdownCard extends StatelessWidget {
  const CountdownCard({super.key, required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        formatDurationClock(remaining),
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w300,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
