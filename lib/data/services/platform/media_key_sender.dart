/// Sends a best-effort play/pause toggle to whatever's currently playing,
/// used to auto-pause media right before the reminder overlay appears. See
/// windows/win_media_key_sender.dart and linux/mpris_media_key_sender.dart.
abstract class MediaKeySender {
  void sendPlayPause();
}
