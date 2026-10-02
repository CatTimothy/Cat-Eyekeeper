import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../data/services/app/window_shell.dart';
import '../../di/injection.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/usage_snapshot.dart';
import '../../domain/use_cases/reminder_scheduler.dart';
import '../../l10n/app_localizations.dart';
import '../core/format.dart';
import '../core/responsive.dart';
import '../core/view_models/dashboard_status_visibility.dart';
import '../core/view_models/settings_view_model.dart';
import '../core/widgets/glass_surface.dart';
import 'view_models/dashboard_view_model.dart';
import 'widgets/app_usage_list.dart';
import 'widgets/category_legend.dart';
import 'widgets/stat_card.dart';
import 'widgets/usage_chart.dart';

/// The main dashboard — 4 status cards, the usage chart with category
/// legend, and the app usage list. Functional spec section 5. Below
/// [kCompactWidthBreakpoint] (the window resized down toward phone
/// width), the chart/app-list pair stacks into a single column and the
/// header/stat-card row reflow instead of cramming into unreadable slivers.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Screen-scoped (registerFactory, not registerSingleton) — a fresh
  // instance every time the dashboard is (re)shown, which is also what
  // makes it reload cleanly from disk after Settings' "clear data" action
  // with no separate invalidation step. See DashboardViewModel's own doc
  // comment.
  late final DashboardViewModel _viewModel = getIt<DashboardViewModel>();
  // Shared with ui/shell/app_shell.dart's title-bar tap-to-collapse — the
  // same get_it singleton, so toggling from either place stays in sync.
  final DashboardStatusVisibility _statusVisibility = getIt<DashboardStatusVisibility>();
  final SettingsViewModel _settingsViewModel = getIt<SettingsViewModel>();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = isCompactWidth(context);
    // The title bar's tap-to-collapse (ui/shell/app_shell.dart) only
    // applies at compact width — always show the cards at desktop width,
    // regardless of whatever this was last toggled to.
    final showStatusCards = !compact || _statusVisibility.visible;

    return ListenableBuilder(
      listenable: Listenable.merge([_viewModel, _statusVisibility, _settingsViewModel]),
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(l10n: l10n, compact: compact),
              const SizedBox(height: 12),
              if (showStatusCards) ...[
                _StatCardsRow(compact: compact, viewModel: _viewModel, settings: _settingsViewModel.current),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: compact
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            _ChartCard(viewModel: _viewModel),
                            const SizedBox(height: 16),
                            SizedBox(height: 360, child: _AppListCard(viewModel: _viewModel)),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _ChartCard(viewModel: _viewModel)),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: _AppListCard(viewModel: _viewModel)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.l10n, required this.compact});

  final AppLocalizations l10n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(l10n.appTitle, style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis),
        ),
        if (kDebugMode)
          _HeaderAction(
            compact: compact,
            icon: Icons.bug_report_outlined,
            label: 'Debug: Open Reminder',
            onPressed: () => getIt<WindowShell>().enterReminderFullscreen(),
          ),
        _HeaderAction(
          compact: compact,
          icon: Icons.settings_outlined,
          label: l10n.dashboardOpenSettings,
          onPressed: () => getIt<WindowShell>().showSettings(),
        ),
        _HeaderAction(
          compact: compact,
          icon: Icons.info_outline,
          label: l10n.dashboardOpenAbout,
          onPressed: () => getIt<WindowShell>().showAbout(),
        ),
      ],
    );
  }
}

/// A labeled text button at desktop widths; collapses to an icon-only
/// button once the window narrows toward phone width, where the full
/// label row would otherwise overflow.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.compact, required this.icon, required this.label, required this.onPressed});

  final bool compact;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(icon: Icon(icon), tooltip: label, onPressed: onPressed);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UsageChart(viewModel: viewModel),
          const SizedBox(height: 12),
          CategoryLegend(
            totalsByCategory: viewModel.categoryTotals ?? const {},
            selected: viewModel.categoryFilter,
            onSelect: viewModel.toggleCategoryFilter,
          ),
        ],
      ),
    );
  }
}

class _AppListCard extends StatelessWidget {
  const _AppListCard({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(padding: const EdgeInsets.all(16), child: AppUsageList(viewModel: viewModel));
  }
}

class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow({required this.compact, required this.viewModel, required this.settings});

  final bool compact;
  final DashboardViewModel viewModel;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = viewModel.liveSnapshot;

    final cards = [
      StatCard(
        label: l10n.dashboardTodayUsage,
        value: formatDurationShort(Duration(seconds: snapshot?.todayUsage.totalActiveSeconds ?? 0)),
      ),
      StatCard(
        label: l10n.dashboardContinuousUsage,
        value: formatDurationShort(Duration(seconds: snapshot?.todayUsage.continuousActiveSeconds ?? 0)),
      ),
      StatCard(label: l10n.dashboardNextBreak, value: _nextBreakValue(l10n, settings, snapshot)),
      StatCard(
        label: l10n.dashboardRunningStatus,
        value: _statusValue(l10n, snapshot),
        detail: _statusDetail(l10n, context, snapshot),
      ),
    ];

    // A 2x2 grid reads much better than 4 slivers once the window
    // narrows toward phone width — each card's label/value/detail text
    // needs real room to stay legible.
    if (compact) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: cards,
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  String _nextBreakValue(AppLocalizations l10n, Settings settings, UsageSnapshot? snapshot) {
    if (!settings.reminderEnabled) return '—';
    final thresholdSeconds = reminderThresholdSeconds(settings);
    final remaining = thresholdSeconds - (snapshot?.todayUsage.continuousActiveSeconds ?? 0);
    return formatDurationShort(Duration(seconds: remaining < 0 ? 0 : remaining));
  }

  String _statusValue(AppLocalizations l10n, UsageSnapshot? snapshot) {
    if (snapshot == null) return l10n.trayStatusIdle;
    if (snapshot.isPaused) return l10n.trayStatusPaused;
    return snapshot.isActive ? l10n.trayStatusActive : l10n.trayStatusIdle;
  }

  /// Idle seconds, then app count, then last-updated time — functional
  /// spec's running status card detail line.
  String? _statusDetail(AppLocalizations l10n, BuildContext context, UsageSnapshot? snapshot) {
    if (snapshot == null) return null;
    final idleSeconds = l10n.dashboardIdleSeconds(snapshot.idleTime.inSeconds);
    final appCount = l10n.dashboardAppCount(snapshot.todayUsage.apps.length);
    final time = intl.DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(snapshot.updatedAt);
    return '$idleSeconds · $appCount · ${l10n.dashboardLastUpdated(time)}';
  }
}
