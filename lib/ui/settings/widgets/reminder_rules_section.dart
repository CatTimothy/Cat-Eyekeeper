import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../view_models/settings_screen_view_model.dart';
import 'settings_group.dart';
import 'validated_number_field.dart';

class ReminderRulesSection extends StatelessWidget {
  const ReminderRulesSection({
    super.key,
    required this.viewModel,
    required this.intervalController,
    required this.breakDurationController,
    required this.idleThresholdController,
  });

  final SettingsScreenViewModel viewModel;
  final TextEditingController intervalController;
  final TextEditingController breakDurationController;
  final TextEditingController idleThresholdController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final draft = viewModel.draft;

    return SettingsGroup(
      title: l10n.settingsGroupReminderRules,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsReminderEnabled),
          value: draft.reminderEnabled,
          onChanged: (value) => viewModel.update((d) => d.copyWith(reminderEnabled: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsAllowCloseFullscreenReminder),
          value: draft.allowCloseFullscreenReminder,
          onChanged: (value) => viewModel.update((d) => d.copyWith(allowCloseFullscreenReminder: value)),
        ),
        ValidatedNumberField(
          label: l10n.settingsReminderInterval,
          controller: intervalController,
          maxDigits: 3,
          suffixText: 'min',
        ),
        ValidatedNumberField(
          label: l10n.settingsBreakDuration,
          controller: breakDurationController,
          maxDigits: 2,
          suffixText: 'min',
        ),
        ValidatedNumberField(
          label: l10n.settingsIdleThreshold,
          controller: idleThresholdController,
          maxDigits: 4,
          suffixText: 'sec',
        ),
      ],
    );
  }
}
