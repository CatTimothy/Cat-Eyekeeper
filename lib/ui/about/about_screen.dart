import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/app/update_service.dart';
import '../../data/services/app/window_shell.dart';
import '../../di/injection.dart';
import '../../l10n/app_localizations.dart';
import '../core/view_models/update_check_view_model.dart';
import 'widgets/link_tile.dart';

/// Project details, privacy statement, links, and update check —
/// functional spec section 7 (requirement 2, new).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final updateService = getIt<UpdateService>();
    final updateCheck = getIt<UpdateCheckViewModel>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => getIt<WindowShell>().showDashboard(),
              ),
              Text(l10n.aboutScreenTitle, style: theme.textTheme.titleLarge),
            ],
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: updateCheck,
              builder: (context, _) => _AboutBody(l10n: l10n, theme: theme, updateService: updateService, updateCheck: updateCheck),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything below the back-button/title row — a plain [StatelessWidget]
/// rebuilt only by the [ListenableBuilder] wrapping it, not by Riverpod:
/// [updateCheck] is a get_it-resolved singleton (see
/// ui/core/view_models/update_check_view_model.dart), shared with
/// ui/settings/settings_screen.dart's own update-check row, so checking
/// for an update from either screen updates both immediately.
class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.l10n, required this.theme, required this.updateService, required this.updateCheck});

  final AppLocalizations l10n;
  final ThemeData theme;
  final UpdateService updateService;
  final UpdateCheckViewModel updateCheck;

  @override
  Widget build(BuildContext context) {
    final currentVersion = updateCheck.currentVersion;
    final isChecking = updateCheck.isChecking;
    final result = updateCheck.result;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            if (currentVersion != null)
              Text(l10n.settingsCurrentVersion('$currentVersion'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(l10n.aboutTagline, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),

            Text(l10n.aboutFeatureSummaryTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.aboutFeatureSummaryBody),
            const SizedBox(height: 24),

            Text(l10n.aboutPrivacyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.settingsPrivacyIntro),
            const SizedBox(height: 4),
            Text('${l10n.settingsPrivacyDoesRecordTitle} ${l10n.settingsPrivacyDoesRecordBody}'),
            const SizedBox(height: 4),
            Text('${l10n.settingsPrivacyDoesNotRecordTitle} ${l10n.settingsPrivacyDoesNotRecordBody}'),
            const SizedBox(height: 24),

            Text(l10n.aboutLinksTitle, style: theme.textTheme.titleMedium),
            LinkTile(
              icon: Icons.home_outlined,
              label: l10n.aboutProjectHomepage,
              onTap: () =>
                  launchUrl(Uri.parse('https://github.com/${updateService.repoOwner}/${updateService.repoName}')),
            ),
            LinkTile(
              icon: Icons.new_releases_outlined,
              label: l10n.aboutReleaseNotes,
              onTap: () => launchUrl(Uri.parse(updateService.releasePageUrl)),
            ),
            LinkTile(
              icon: Icons.favorite_outline,
              label: l10n.aboutAcknowledgements,
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: currentVersion?.toString(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: isChecking ? null : updateCheck.checkForUpdates,
                  child: Text(isChecking ? l10n.settingsCheckingForUpdates : l10n.settingsCheckForUpdates),
                ),
                if (result != null)
                  Expanded(
                    child: Text(
                      result.hasUpdate ? l10n.settingsUpdateAvailable('${result.latest.version}') : l10n.settingsUpToDate,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
