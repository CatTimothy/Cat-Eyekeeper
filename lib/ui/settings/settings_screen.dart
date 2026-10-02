import 'package:flutter/material.dart';

import '../../data/services/app/window_shell.dart';
import '../../di/injection.dart';
import '../../domain/models/update_check_result.dart';
import '../../l10n/app_localizations.dart';
import '../core/view_models/update_check_view_model.dart';
import 'view_models/settings_screen_view_model.dart';
import 'widgets/appearance_section.dart';
import 'widgets/privacy_notice_section.dart';
import 'widgets/reminder_rules_section.dart';
import 'widgets/system_behavior_section.dart';

const _reminderIntervalRange = (min: 1, max: 240);
const _breakDurationRange = (min: 1, max: 60);
const _idleThresholdRange = (min: 10, max: 3600);

/// The single settings screen shared by the dashboard's settings button
/// and the tray's "Settings" menu item (functional spec requirement 1) —
/// both just call `windowShell.showSettings()`, which renders this same
/// widget. Draft/Save/Cancel per functional spec section 6.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Screen-scoped (registerFactory) — a fresh instance every time the
  // settings screen is shown, starting from SettingsViewModel.current, so
  // there's nothing to remember to reset on re-entry. See
  // SettingsScreenViewModel's own doc comment.
  late final SettingsScreenViewModel _viewModel = getIt<SettingsScreenViewModel>();
  late final TextEditingController _intervalController;
  late final TextEditingController _breakDurationController;
  late final TextEditingController _idleThresholdController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initial = _viewModel.draft;
    _intervalController = TextEditingController(text: '${initial.reminderIntervalMinutes}');
    _breakDurationController = TextEditingController(text: '${initial.breakDurationMinutes}');
    _idleThresholdController = TextEditingController(text: '${initial.idleThresholdSeconds}');
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _intervalController.dispose();
    _breakDurationController.dispose();
    _idleThresholdController.dispose();
    super.dispose();
  }

  int? _parseInRange(String text, ({int min, int max}) range) {
    final value = int.tryParse(text);
    if (value == null || value < range.min || value > range.max) return null;
    return value;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final interval = _parseInRange(_intervalController.text, _reminderIntervalRange);
    final breakDuration = _parseInRange(_breakDurationController.text, _breakDurationRange);
    final idleThreshold = _parseInRange(_idleThresholdController.text, _idleThresholdRange);

    if (interval == null) {
      setState(() => _errorMessage = l10n.settingsValidationRange(_reminderIntervalRange.min, _reminderIntervalRange.max));
      return;
    }
    if (breakDuration == null) {
      setState(() => _errorMessage = l10n.settingsValidationRange(_breakDurationRange.min, _breakDurationRange.max));
      return;
    }
    if (idleThreshold == null) {
      setState(() => _errorMessage = l10n.settingsValidationRange(_idleThresholdRange.min, _idleThresholdRange.max));
      return;
    }

    setState(() => _errorMessage = null);

    final draft = _viewModel.draft.copyWith(
      reminderIntervalMinutes: interval,
      breakDurationMinutes: breakDuration,
      idleThresholdSeconds: idleThreshold,
    );
    await _viewModel.save(draft);
    if (mounted) getIt<WindowShell>().showDashboard();
  }

  void _cancel() => getIt<WindowShell>().showDashboard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsScreenTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Expanded(
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Clamped rather than a hardcoded 340 — a phone-width
                    // window (see main.dart's WindowOptions.minimumSize) is
                    // narrower than that, which would otherwise overflow.
                    final sectionWidth = constraints.maxWidth < 340 ? constraints.maxWidth : 340.0;
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: sectionWidth,
                            child: ReminderRulesSection(
                              viewModel: _viewModel,
                              intervalController: _intervalController,
                              breakDurationController: _breakDurationController,
                              idleThresholdController: _idleThresholdController,
                            ),
                          ),
                          SizedBox(width: sectionWidth, child: AppearanceSection(viewModel: _viewModel)),
                          Column(
                            children: [
                              SizedBox(width: sectionWidth, child: SystemBehaviorSection(viewModel: _viewModel)),
                              const SizedBox(height: 16),
                              SizedBox(width: sectionWidth, child: const PrivacyNoticeSection()),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const _UpdateStatusRow(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: _cancel, child: Text(l10n.cancel)),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: Text(l10n.save)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateStatusRow extends StatelessWidget {
  const _UpdateStatusRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Shared with ui/about/about_screen.dart's own update-check row — the
    // same get_it singleton (see ui/core/view_models/update_check_view_model.dart),
    // so checking for an update here also updates About immediately.
    final updateCheck = getIt<UpdateCheckViewModel>();

    return ListenableBuilder(
      listenable: updateCheck,
      builder: (context, _) {
        final currentVersion = updateCheck.currentVersion;
        final isChecking = updateCheck.isChecking;
        final result = updateCheck.result;

        return Row(
          children: [
            Text(currentVersion == null ? '' : l10n.settingsCurrentVersion('$currentVersion')),
            const SizedBox(width: 12),
            TextButton(
              onPressed: isChecking ? null : updateCheck.checkForUpdates,
              child: Text(isChecking ? l10n.settingsCheckingForUpdates : l10n.settingsCheckForUpdates),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_statusText(l10n, isChecking, result), overflow: TextOverflow.ellipsis)),
          ],
        );
      },
    );
  }

  String _statusText(AppLocalizations l10n, bool isChecking, UpdateCheckResult? result) {
    if (isChecking || result == null) return '';
    return result.hasUpdate ? l10n.settingsUpdateAvailable('${result.latest.version}') : l10n.settingsUpToDate;
  }
}
