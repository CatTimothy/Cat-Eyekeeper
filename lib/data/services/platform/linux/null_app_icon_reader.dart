import 'dart:typed_data';

import '../app_icon_reader.dart';

/// Desktop-file icon-theme lookup (the Linux equivalent of Explorer's
/// per-exe icon) is a much larger, unverified undertaking than the rest of
/// this app's Linux support — always returns null so the dashboard falls
/// back to its letter avatar instead of guessing wrong.
class NullAppIconReader implements AppIconReader {
  const NullAppIconReader();

  @override
  Uint8List? read(String executablePath) => null;
}
