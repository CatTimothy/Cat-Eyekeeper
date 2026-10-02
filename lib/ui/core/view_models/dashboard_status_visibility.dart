import '../base_view_model.dart';

/// Whether the dashboard's 4 stat cards are shown — toggled by tapping
/// the title bar at compact/mobile window widths
/// (ui/shell/app_shell.dart), trading the status cards for more
/// chart/app-list room. Only consulted at compact width;
/// ui/dashboard/dashboard_screen.dart always shows the cards at desktop
/// width regardless of this flag. Shared between shell/ (the title bar
/// lives there) and dashboard/ — a get_it singleton, not owned by
/// DashboardViewModel, which is screen-scoped and torn down when the
/// dashboard isn't showing.
class DashboardStatusVisibility extends BaseViewModel {
  bool _visible = true;
  bool get visible => _visible;

  void toggle() {
    _visible = !_visible;
    safeNotifyListeners();
  }
}
