import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../idle_reader.dart';

/// Reads keyboard/mouse idle time via `GetLastInputInfo`.
class WinIdleReader implements IdleReader {
  @override
  Duration idleTime() {
    final info = calloc<LASTINPUTINFO>();
    try {
      info.ref.cbSize = sizeOf<LASTINPUTINFO>();
      if (GetLastInputInfo(info) == 0) return Duration.zero;

      // Both GetTickCount() and dwTime are 32-bit unsigned tick counts;
      // mask to 32 bits so the subtraction wraps the same way it does on
      // the Windows side rather than going negative in Dart's 64-bit ints.
      final elapsedTicks = (GetTickCount() - info.ref.dwTime) & 0xFFFFFFFF;
      return Duration(milliseconds: elapsedTicks);
    } finally {
      calloc.free(info);
    }
  }
}
