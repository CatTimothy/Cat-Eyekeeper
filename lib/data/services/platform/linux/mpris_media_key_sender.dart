import 'dart:async';

import 'package:dbus/dbus.dart';

import '../media_key_sender.dart';

/// Sends a `Pause` call to every active MPRIS media player on the session
/// bus (`org.mpris.MediaPlayer2.*`) — the Linux equivalent of a hardware
/// media key. There's no single "pause whatever is playing" call on
/// Linux, so this iterates every MPRIS-compliant player found and pauses
/// each independently.
class MprisMediaKeySender implements MediaKeySender {
  @override
  void sendPlayPause() {
    // Fire-and-forget: the reminder overlay shouldn't block on this.
    unawaited(_pauseAllPlayers());
  }

  Future<void> _pauseAllPlayers() async {
    final client = DBusClient.session();
    try {
      final names = await client.listNames();
      final playerNames = names.where((name) => name.startsWith('org.mpris.MediaPlayer2.'));
      for (final name in playerNames) {
        final player = DBusRemoteObject(client, name: name, path: DBusObjectPath('/org/mpris/MediaPlayer2'));
        try {
          await player.callMethod('org.mpris.MediaPlayer2.Player', 'Pause', const []);
        } catch (_) {
          // Best-effort: a player that errors on Pause shouldn't stop us
          // from pausing the others.
        }
      }
    } finally {
      await client.close();
    }
  }
}
