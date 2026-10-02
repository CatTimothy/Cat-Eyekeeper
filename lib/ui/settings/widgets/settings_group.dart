import 'package:flutter/material.dart';

import '../../core/widgets/glass_surface.dart';

/// A titled card section, used by every group on the settings screen.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ],
      ),
    );
  }
}
