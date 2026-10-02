import '../models/foreground_app.dart';
import '../models/reminder_suppression_reason.dart';

const Set<String> _presentationProcesses = {'powerpnt', 'wpp', 'wpsoffice'};

const Set<String> _mediaProcesses = {
  'vlc',
  'mpv',
  'potplayer',
  'potplayermini64',
  'iina',
  'wmplayer',
  'quicktimeplayer',
  'mpc-hc64',
  'mpc-be64',
};

const Set<String> _browserProcesses = {'chrome', 'msedge', 'firefox', 'brave', 'opera', 'vivaldi', 'arc'};

const Set<String> _mediaTitleKeywords = {
  'youtube',
  'bilibili',
  '哔哩哔哩',
  'netflix',
  'twitch',
  'iqiyi',
  '爱奇艺',
  'youku',
  '优酷',
  '腾讯视频',
  'douyin',
  '抖音',
  '西瓜视频',
  '芒果tv',
  '视频',
  'video',
};

const Set<String> _presentationTitleKeywords = {
  'slide show',
  'presenter view',
  'powerpoint',
  '幻灯片放映',
  '演示者视图',
};

/// Returns why a due reminder should be held back — mid-presentation or
/// watching fullscreen video — or null if it's free to fire. See
/// functional spec section 3 ("抑制規則").
ReminderSuppressionReason? suppressReminder(ForegroundApp? app) {
  if (app == null) return null;

  final processName = app.processName.toLowerCase();
  final windowTitle = app.windowTitle.toLowerCase();

  final isPresenting =
      _presentationProcesses.contains(processName) &&
      (app.isFullScreen || _containsAny(windowTitle, _presentationTitleKeywords));
  if (isPresenting) return ReminderSuppressionReason.presenting;

  if (!app.isFullScreen) return null;

  if (isMediaPlaybackApp(app)) return ReminderSuppressionReason.fullscreenVideo;
  return null;
}

/// True if [app] is a known media player, or a known browser whose window
/// title suggests it's playing video. Also used to decide whether to send
/// a pause command before showing the reminder overlay.
bool isMediaPlaybackApp(ForegroundApp app) {
  final processName = app.processName.toLowerCase();
  if (_mediaProcesses.contains(processName)) return true;
  if (_browserProcesses.contains(processName)) {
    return _containsAny(app.windowTitle.toLowerCase(), _mediaTitleKeywords);
  }
  return false;
}

bool _containsAny(String haystack, Set<String> keywords) {
  if (haystack.trim().isEmpty) return false;
  return keywords.any((keyword) => haystack.contains(keyword));
}
