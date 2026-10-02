import 'package:flutter/material.dart';

import '../../../data/repositories/usage_repository.dart';
import '../../../di/injection.dart';
import '../../../domain/use_cases/tracking_engine.dart';
import '../../../l10n/app_localizations.dart';
import 'settings_group.dart';

/// Deletes all persisted usage history and resets today's live tracking
/// state to match (Settings' "clear data" action). Irreversible — the
/// caller must confirm with the user before calling this. No Dashboard-side
/// invalidation needed: DashboardViewModel is screen-scoped and reloads
/// from disk on construction, so the next time the dashboard is shown it
/// reflects the cleared state automatically (see its own doc comment).
Future<void> _clearAllUsageData() async {
  await getIt<UsageRepository>().clearAll();
  await getIt<TrackingEngine>().resetToday();
}

/// Static privacy notice plus a "clear data" control (functional spec
/// section 9) that permanently deletes all recorded usage history.
class PrivacyNoticeSection extends StatefulWidget {
  const PrivacyNoticeSection({super.key});

  @override
  State<PrivacyNoticeSection> createState() => _PrivacyNoticeSectionState();
}

class _PrivacyNoticeSectionState extends State<PrivacyNoticeSection> {
  bool _isClearing = false;

  Future<void> _confirmAndClear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsClearDataConfirmTitle),
        content: Text(l10n.settingsClearDataConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsClearDataConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      await _clearAllUsageData();
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsClearDataSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return SettingsGroup(
      title: l10n.settingsGroupPrivacy,
      children: [
        Text(l10n.settingsPrivacyIntro),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsPrivacyDoesRecordTitle, style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(l10n.settingsPrivacyDoesRecordBody, style: mutedStyle),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsPrivacyDoesNotRecordTitle, style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(l10n.settingsPrivacyDoesNotRecordBody, style: mutedStyle),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _isClearing ? null : _confirmAndClear,
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            icon: _isClearing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline),
            label: Text(l10n.settingsClearDataButton),
          ),
        ),
      ],
    );
  }
}
