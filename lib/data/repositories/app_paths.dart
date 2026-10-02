import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/date_stamp.dart';

/// Resolves and creates the application's on-disk data directory:
/// `%APPDATA%\cat_eyekeeper` on Windows, `$XDG_DATA_HOME/cat_eyekeeper`
/// (falling back to `~/.local/share/cat_eyekeeper`) on Linux. Deliberately
/// not `ScreenTime` — this app is an independent implementation and must
/// not read/write another unrelated app's data directory of the same
/// obvious name.
class AppPaths {
  AppPaths({String? overrideBaseDirectory, String? overrideBundledAssetsRoot})
    : baseDirectory = overrideBaseDirectory ?? _resolveBaseDirectory(),
      _bundledAssetsRoot = overrideBundledAssetsRoot;

  final String baseDirectory;

  /// Overrides the root [resolveBundledAsset] joins asset paths onto —
  /// tests point this at the project root (which has a real `assets/`
  /// folder in source form) instead of the production
  /// `<executable>/data/flutter_assets` layout, so bundled defaults can be
  /// resolved without a full `flutter build` first.
  final String? _bundledAssetsRoot;

  String get usageDirectory => p.join(baseDirectory, 'usage');
  String get logDirectory => p.join(baseDirectory, 'logs');
  String get settingsFile => p.join(baseDirectory, 'settings.json');
  String get categoryRulesFile => p.join(baseDirectory, 'category_rules.json');

  String usageFile(DateTime date) => p.join(usageDirectory, '${formatDateStamp(date)}.json');

  /// Resolves a bundled asset (declared under pubspec.yaml's
  /// `flutter.assets`, e.g. `assets/bundled_packs/reminder_animation/star_cat/start_video.webm`)
  /// to a real file on disk, rather than a Flutter asset-bundle key — the
  /// reminder's default animation (`VideoPlayerController.file`) and tray
  /// icon generation (`File(...)`) both need an actual path, not
  /// `rootBundle`. Both the Windows and Linux desktop runners copy
  /// `flutter.assets` verbatim into a `data/flutter_assets/` folder next to
  /// the executable (see windows/runner/main.cpp's `DartProject(L"data")`
  /// and linux/CMakeLists.txt's `FLUTTER_ASSET_DIR_NAME`), true in both
  /// `flutter run` and a packaged install.
  String resolveBundledAsset(String assetPath) => p.join(
    _bundledAssetsRoot ?? p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets'),
    assetPath,
  );

  Future<void> ensureCreated() async {
    await Directory(baseDirectory).create(recursive: true);
    await Directory(usageDirectory).create(recursive: true);
    await Directory(logDirectory).create(recursive: true);
  }

  static String _resolveBaseDirectory() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) {
        throw StateError('APPDATA environment variable is not set.');
      }
      return p.join(appData, 'cat_eyekeeper');
    }
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    final base = (xdgDataHome != null && xdgDataHome.isNotEmpty)
        ? xdgDataHome
        : p.join(_homeDirectory(), '.local', 'share');
    return p.join(base, 'cat_eyekeeper');
  }

  static String _homeDirectory() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('HOME environment variable is not set.');
    }
    return home;
  }
}
