import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../media_key_sender.dart';

/// Synthesizes a media play/pause key press+release via `SendInput`, used
/// to auto-pause video before the reminder overlay appears.
class WinMediaKeySender implements MediaKeySender {
  @override
  void sendPlayPause() {
    final inputs = calloc<INPUT>(2);
    try {
      inputs[0].type = INPUT_KEYBOARD;
      inputs[0].ki.wVk = VK_MEDIA_PLAY_PAUSE;
      inputs[0].ki.dwFlags = 0;

      inputs[1].type = INPUT_KEYBOARD;
      inputs[1].ki.wVk = VK_MEDIA_PLAY_PAUSE;
      inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;

      SendInput(2, inputs, sizeOf<INPUT>());
    } finally {
      calloc.free(inputs);
    }
  }
}
