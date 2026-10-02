import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/models/settings.dart';
import '../../../theme/app_colors.dart';

/// Opens the custom-theme color picker as an in-app floating [Dialog] —
/// not a separate OS window, consistent with this app's single-window
/// architecture. Returns the edited [CustomThemeColors], or null if the
/// user cancelled.
Future<CustomThemeColors?> showCustomThemeDialog(BuildContext context, CustomThemeColors initial) {
  return showDialog<CustomThemeColors>(context: context, builder: (context) => _CustomThemeDialog(initial: initial));
}

class _CustomThemeDialog extends StatefulWidget {
  const _CustomThemeDialog({required this.initial});

  final CustomThemeColors initial;

  @override
  State<_CustomThemeDialog> createState() => _CustomThemeDialogState();
}

class _CustomThemeDialogState extends State<_CustomThemeDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late CustomThemeColors _current;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _current = widget.initial;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Clamped rather than a hardcoded 380 — a phone-width window (see
    // main.dart's WindowOptions.minimumSize) is narrower than that,
    // which would otherwise overflow past the screen edge.
    final maxDialogWidth = MediaQuery.sizeOf(context).width - 48;

    return Dialog(
      child: SizedBox(
        width: maxDialogWidth < 380 ? maxDialogWidth : 380,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.customThemeDialogTitle, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            _PreviewStrip(colors: _current),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.customThemeBackground),
                Tab(text: l10n.customThemeWidgets),
                Tab(text: l10n.customThemeAccent),
                Tab(text: l10n.customThemeText),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ColorEditor(
                    color: colorFromHex(_current.backgroundColorHex),
                    opacity: _current.backgroundOpacity,
                    showOpacity: true,
                    l10n: l10n,
                    onColorChanged: (c) => setState(() => _current = _current.copyWith(backgroundColorHex: colorToHex(c))),
                    onOpacityChanged: (o) => setState(() => _current = _current.copyWith(backgroundOpacity: o)),
                  ),
                  _ColorEditor(
                    color: colorFromHex(_current.widgetsColorHex),
                    opacity: _current.widgetsOpacity,
                    showOpacity: true,
                    l10n: l10n,
                    onColorChanged: (c) => setState(() => _current = _current.copyWith(widgetsColorHex: colorToHex(c))),
                    onOpacityChanged: (o) => setState(() => _current = _current.copyWith(widgetsOpacity: o)),
                  ),
                  _ColorEditor(
                    color: colorFromHex(_current.accentColorHex),
                    opacity: 1,
                    showOpacity: false,
                    l10n: l10n,
                    onColorChanged: (c) => setState(() => _current = _current.copyWith(accentColorHex: colorToHex(c))),
                    onOpacityChanged: (_) {},
                  ),
                  _ColorEditor(
                    color: colorFromHex(_current.textColorHex),
                    opacity: 1,
                    showOpacity: false,
                    l10n: l10n,
                    onColorChanged: (c) => setState(() => _current = _current.copyWith(textColorHex: colorToHex(c))),
                    onOpacityChanged: (_) {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () => Navigator.of(context).pop(_current), child: Text(l10n.customThemeApply)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({required this.colors});

  final CustomThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      decoration: BoxDecoration(
        color: colorFromHex(colors.backgroundColorHex).withValues(alpha: colors.backgroundOpacity),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 200,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorFromHex(colors.widgetsColorHex).withValues(alpha: colors.widgetsOpacity),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colorFromHex(colors.accentColorHex), width: 2),
        ),
        child: Text('Aa', style: TextStyle(color: colorFromHex(colors.textColorHex), fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ColorEditor extends StatelessWidget {
  const _ColorEditor({
    required this.color,
    required this.opacity,
    required this.showOpacity,
    required this.l10n,
    required this.onColorChanged,
    required this.onOpacityChanged,
  });

  final Color color;
  final double opacity;
  final bool showOpacity;
  final AppLocalizations l10n;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ColorPicker(
            color: color,
            onColorChanged: onColorChanged,
            enableOpacity: false,
            pickersEnabled: const {
              ColorPickerType.wheel: true,
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
            },
            wheelDiameter: 220,
            width: 32,
            height: 32,
          ),
          if (showOpacity) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.customThemeOpacity),
                Expanded(
                  child: Slider(
                    value: opacity,
                    divisions: 20,
                    label: '${(opacity * 100).round()}%',
                    onChanged: onOpacityChanged,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
