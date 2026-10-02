import 'package:freezed_annotation/freezed_annotation.dart';

part 'foreground_app.freezed.dart';

/// A snapshot of the currently-focused window/process. Not persisted to
/// disk directly — core/tracking_engine.dart folds it into [AppUsage]
/// entries inside a [DailyUsage].
@freezed
abstract class ForegroundApp with _$ForegroundApp {
  const ForegroundApp._();

  const factory ForegroundApp({
    required int processId,
    required String name,
    required String processName,
    required String executablePath,
    required String windowTitle,
    required bool isFullScreen,
  }) = _ForegroundApp;

  /// Canonical identity for grouping usage: the executable path when known,
  /// falling back to the process name (e.g. for sandboxed/protected
  /// processes whose path can't be resolved).
  String get appId => executablePath.trim().isNotEmpty ? executablePath : processName;
}
