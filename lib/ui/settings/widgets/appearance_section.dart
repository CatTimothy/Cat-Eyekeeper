import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/models/settings.dart';
import '../view_models/settings_screen_view_model.dart';
import 'custom_theme_dialog.dart';
import 'settings_group.dart';

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.viewModel});

  final SettingsScreenViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final draft = viewModel.draft;

    return SettingsGroup(
      title: l10n.settingsGroupAppearance,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _LabeledDropdown<AppThemeMode>(
                label: l10n.settingsThemeMode,
                value: draft.themeMode,
                items: {
                  AppThemeMode.system: l10n.settingsThemeSystem,
                  AppThemeMode.light: l10n.settingsThemeLight,
                  AppThemeMode.dark: l10n.settingsThemeDark,
                  AppThemeMode.glass: l10n.settingsThemeGlass,
                  AppThemeMode.custom: l10n.settingsThemeCustom,
                },
                // Theme changes apply immediately (unlike every other
                // setting on this screen, which waits for Save) — see
                // SettingsScreenViewModel.saveImmediately.
                onChanged: (mode) => viewModel.saveImmediately((s) => s.copyWith(themeMode: mode)),
              ),
            ),
            if (draft.themeMode == AppThemeMode.custom) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final result = await showCustomThemeDialog(
                    context,
                    draft.customThemeColors ?? CustomThemeColors.defaults(),
                  );
                  if (result == null) return;
                  await viewModel.saveImmediately((s) => s.copyWith(customThemeColors: result));
                },
                child: Text(l10n.settingsCustomizeButton),
              ),
            ],
          ],
        ),
        _LabeledDropdown<AppLanguage>(
          label: l10n.settingsLanguage,
          value: draft.language,
          items: {
            AppLanguage.system: l10n.settingsLanguageSystem,
            AppLanguage.zh: l10n.settingsLanguageZh,
            AppLanguage.zhHant: l10n.settingsLanguageZhHant,
            AppLanguage.en: l10n.settingsLanguageEn,
          },
          onChanged: (language) => viewModel.update((d) => d.copyWith(language: language)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsOverlayBlur),
            Slider(
              value: draft.overlayBlurStrength,
              divisions: 20,
              label: '${(draft.overlayBlurStrength * 100).round()}%',
              onChanged: (value) => viewModel.update((d) => d.copyWith(overlayBlurStrength: value)),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsTrayAnimation),
          value: draft.trayReminderAnimationEnabled,
          onChanged: (value) => viewModel.update((d) => d.copyWith(trayReminderAnimationEnabled: value)),
        ),
      ],
    );
  }
}

/// A fully-controlled dropdown (plain [DropdownButton], not
/// [DropdownButtonFormField] — the latter's `initialValue` only seeds
/// once and won't reactively track external state changes).
class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ],
    );
  }
}
