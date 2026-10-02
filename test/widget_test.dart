// Phase 4 smoke test: the app boots under a real (but temp-dir-scoped)
// get_it container and renders with the localized app title. Uses a plain
// placeholder `home` rather than the real AppShell — AppShell drives
// window_manager/tray_manager/local_notifier, which aren't backed by real
// native plugins under `flutter test` (only under `flutter run`); the
// full integrated shell is verified by actually running the app instead.
//
// configureDependencies() does real file I/O, which must happen in setUp()
// rather than inside the testWidgets() callback — real dart:io calls made
// inside the testWidgets zone hang indefinitely on this toolchain/host
// combination (confirmed in isolation: even a bare `Directory.create()`
// hangs inside testWidgets() but completes instantly in setUp()/setUpAll()).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cat_eyekeeper/app.dart';
import 'package:cat_eyekeeper/data/repositories/app_paths.dart';
import 'package:cat_eyekeeper/di/injection.dart';
import 'package:cat_eyekeeper/l10n/app_localizations.dart';
import 'package:cat_eyekeeper/ui/core/view_models/view_model_injection.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('cat_eyekeeper_widget_test_');
    await configureDependencies(paths: AppPaths(overrideBaseDirectory: tempDir.path));
    configureViewModels(getIt);
  });

  tearDown(() async {
    // AppLifecycle.dispose() touches tray_manager, which (like window_manager
    // and local_notifier) has no real plugin implementation under
    // `flutter test` and throws MissingPluginException — expected here,
    // not a real failure, so it's swallowed rather than failing the test.
    try {
      await getIt<AppLifecycle>().dispose();
    } on Object {
      // ignore
    }
    // Resets the container so a later test file's own get_it usage (or a
    // re-run of this one) never sees a stale registration from this run.
    await getIt.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('app boots and shows the localized app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenTimeApp(
        home: Scaffold(
          body: Builder(builder: (context) => Center(child: Text(AppLocalizations.of(context)!.appTitle))),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cat Eyekeeper'), findsOneWidget);
  });
}
