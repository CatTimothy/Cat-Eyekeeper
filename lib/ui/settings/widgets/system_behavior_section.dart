import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../view_models/settings_screen_view_model.dart';
import 'settings_group.dart';

class SystemBehaviorSection extends StatelessWidget {
  const SystemBehaviorSection({super.key, required this.viewModel});

  final SettingsScreenViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final draft = viewModel.draft;

    return SettingsGroup(
      title: l10n.settingsGroupSystemBehavior,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsLaunchAtStartup),
          value: draft.launchAtStartup,
          onChanged: (value) => viewModel.update((d) => d.copyWith(launchAtStartup: value)),
        ),
      ],
    );
  }
}
