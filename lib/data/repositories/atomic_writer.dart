import 'dart:io';
import 'dart:math';

/// Writes a file via a temp-file-then-rename so a crash or concurrent
/// reader never observes a half-written file. Retries the rename a few
/// times with backoff, since Windows can transiently refuse to replace a
/// file that's momentarily locked (e.g. by an antivirus scanner).
class AtomicWriter {
  const AtomicWriter();

  Future<void> writeString(String path, String content) async {
    final target = File(path);
    await target.parent.create(recursive: true);
    final tempFile = File('$path.${_randomSuffix()}.tmp');
    try {
      await tempFile.writeAsString(content, flush: true);
      await _replace(tempFile.path, path);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Best-effort cleanup: a stray temp file is less harmful than
          // throwing out of a finally block.
        }
      }
    }
  }

  Future<void> _replace(String tempPath, String path) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await File(tempPath).rename(path);
        return;
      } on FileSystemException {
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 75 * attempt));
      }
    }
  }

  String _randomSuffix() {
    final rand = Random.secure();
    return List.generate(8, (_) => rand.nextInt(16).toRadixString(16)).join();
  }
}
