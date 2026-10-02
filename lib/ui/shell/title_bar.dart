import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// A custom draggable title bar — the window itself is frameless
/// (`TitleBarStyle.hidden` in main.dart) — shared by every top-level
/// screen. The drag region excludes the caption buttons so clicks on them
/// don't get eaten by the drag gesture.
class TitleBar extends StatefulWidget {
  const TitleBar({super.key, required this.title, this.leading, this.onTap, this.tappedIndicator});

  final String title;

  /// Optional extra content (e.g. settings/about buttons) placed before
  /// the caption buttons, after the draggable title area.
  final Widget? leading;

  /// Optional tap handler for the draggable title area — e.g.
  /// ui/shell/app_shell.dart wires this to toggle the dashboard's stat
  /// cards at compact/mobile widths. Fires alongside (not instead of) the
  /// existing drag/double-tap-to-maximize gestures.
  final VoidCallback? onTap;

  /// A small passive hint shown right after the title when [onTap] is
  /// set — e.g. a chevron indicating the dashboard cards' current
  /// shown/hidden state — so the tap target doesn't look like plain
  /// static text.
  final Widget? tappedIndicator;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) setState(() => _isMaximized = value);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  void _toggleMaximize() => _isMaximized ? windowManager.unmaximize() : windowManager.maximize();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              onTap: widget.onTap,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Image.asset('assets/icon/app_icon.png', width: 18, height: 18),
                  const SizedBox(width: 8),
                  Text(widget.title, style: theme.textTheme.titleSmall),
                  if (widget.tappedIndicator != null) ...[const SizedBox(width: 4), widget.tappedIndicator!],
                ],
              ),
            ),
          ),
          if (widget.leading != null) widget.leading!,
          _CaptionButton(icon: Icons.remove, onPressed: windowManager.minimize),
          _CaptionButton(
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            onPressed: _toggleMaximize,
          ),
          _CaptionButton(icon: Icons.close, onPressed: windowManager.close, isClose: true),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({required this.icon, required this.onPressed, this.isClose = false});

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 46,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isClose ? Colors.red.withValues(alpha: 0.85) : onSurface.withValues(alpha: 0.08),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}
