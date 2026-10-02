import 'dart:io';

import '../../repositories/app_paths.dart';

/// Append-only crash/error log at `{appData}/logs/app.log`. Logging must
/// never throw — a failure here should never crash the app it's trying to
/// log for.
class AppLogger {
  AppLogger({required AppPaths paths}) : _paths = paths;

  final AppPaths _paths;

  // Chains every write onto the previous one so concurrent log() calls
  // can't interleave their bytes in the file.
  Future<void> _writeQueue = Future.value();

  Future<void> log(Object error, {StackTrace? stackTrace, String? context}) {
    final next = _writeQueue.then((_) => _append(error, stackTrace, context));
    _writeQueue = next;
    return next;
  }

  Future<void> _append(Object error, StackTrace? stackTrace, String? context) async {
    try {
      await _paths.ensureCreated();
      final file = File('${_paths.logDirectory}/app.log');
      final buffer = StringBuffer()
        ..writeln('[${DateTime.now().toIso8601String()}] ${context ?? ''}')
        ..writeln(error.toString());
      if (stackTrace != null) buffer.writeln(stackTrace.toString());
      buffer.writeln();
      await file.writeAsString(buffer.toString(), mode: FileMode.append, flush: true);
    } catch (_) {
      // Swallow: logging failures must not cascade into more failures.
    }
  }
}
