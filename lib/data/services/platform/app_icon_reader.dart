import 'dart:typed_data';

/// Reads an application's icon (the same one Explorer/Finder shows), keyed
/// by executable path, encoded as PNG bytes so the UI can render it with
/// `Image.memory` without any platform-specific widget. See
/// windows/win_app_icon_reader.dart — Linux has no implementation yet
/// (desktop-file icon-theme lookup is a much larger, unverified
/// undertaking); the dashboard falls back to a letter avatar wherever this
/// returns null.
abstract class AppIconReader {
  /// Returns null if the icon can't be extracted (missing/inaccessible
  /// file, no icon resource, or the platform doesn't support this).
  Uint8List? read(String executablePath);
}
