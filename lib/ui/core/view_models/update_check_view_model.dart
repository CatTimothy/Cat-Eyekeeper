import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../../data/services/app/update_service.dart';
import '../../../domain/models/update_check_result.dart';
import '../../../domain/use_cases/app_version.dart';
import '../base_view_model.dart';

/// Update-check state shared by every screen that shows it (About,
/// Settings) — a single get_it singleton rather than per-screen state, so
/// checking for an update from either screen updates both immediately.
/// Functional spec section 8.
class UpdateCheckViewModel extends BaseViewModel {
  UpdateCheckViewModel({required this.updateService}) {
    _loadCurrentVersion();
  }

  final UpdateService updateService;

  Version? _currentVersion;
  Version? get currentVersion => _currentVersion;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// Null until the first check completes, and stays null if every retry
  /// fails (distinct from a completed check that simply found no update,
  /// which is a non-null result with `hasUpdate: false`).
  UpdateCheckResult? _result;
  UpdateCheckResult? get result => _result;

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = parseReleaseTag(info.version) ?? Version(0, 0, 0);
      safeNotifyListeners();
    } on Object {
      // Matches the pre-ViewModel behavior (a FutureProvider whose error
      // branch rendered nothing): leaves currentVersion null rather than
      // crashing — package_info_plus has no real platform implementation
      // under `flutter test`, and a transient plugin failure shouldn't be
      // fatal in production either.
    }
  }

  Future<void> checkForUpdates() async {
    _isChecking = true;
    safeNotifyListeners();
    try {
      final current = _currentVersion ?? Version(0, 0, 0);
      _result = await updateService.checkWithRetry(current);
    } finally {
      _isChecking = false;
      safeNotifyListeners();
    }
  }
}
