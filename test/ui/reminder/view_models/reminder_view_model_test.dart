import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/services/app/desktop_backdrop_service.dart';
import 'package:cat_eyekeeper/data/services/platform/media_key_sender.dart';
import 'package:cat_eyekeeper/domain/models/category_rule.dart';
import 'package:cat_eyekeeper/domain/models/daily_usage.dart';
import 'package:cat_eyekeeper/domain/models/date_stamp.dart';
import 'package:cat_eyekeeper/domain/models/foreground_app.dart';
import 'package:cat_eyekeeper/domain/models/settings.dart';
import 'package:cat_eyekeeper/domain/use_cases/category_classifier.dart';
import 'package:cat_eyekeeper/domain/use_cases/idle_detector.dart';
import 'package:cat_eyekeeper/domain/use_cases/reminder_scheduler.dart';
import 'package:cat_eyekeeper/domain/use_cases/tracking_engine.dart';
import 'package:cat_eyekeeper/ui/reminder/view_models/reminder_view_model.dart';

import '../../../data/fakes/in_memory_usage_repository.dart';
import '../../../platform/fakes/fake_desktop_capture_reader.dart';
import '../../../platform/fakes/fake_foreground_reader.dart';
import '../../../platform/fakes/fake_idle_reader.dart';

class _FakeMediaKeySender implements MediaKeySender {
  int playPauseCount = 0;

  @override
  void sendPlayPause() => playPauseCount++;
}

final _codeApp = ForegroundApp(
  processId: 1,
  name: 'Visual Studio Code',
  processName: 'code',
  executablePath: 'C:\\apps\\code.exe',
  windowTitle: 'main.dart - Visual Studio Code',
  isFullScreen: false,
);

final _vlcApp = ForegroundApp(
  processId: 2,
  name: 'VLC',
  processName: 'vlc',
  executablePath: 'C:\\apps\\vlc.exe',
  windowTitle: 'movie.mkv - VLC',
  isFullScreen: false,
);

void main() {
  late DateTime clock;
  late TrackingEngine trackingEngine;
  late ReminderScheduler reminderScheduler;
  late DesktopBackdropService desktopBackdropService;
  late _FakeMediaKeySender mediaKeySender;

  setUp(() {
    clock = DateTime.now();
    final idleReader = FakeIdleReader()..idleDuration = Duration.zero;
    final foregroundReader = FakeForegroundReader(app: _codeApp);
    trackingEngine = TrackingEngine(
      idleDetector: IdleDetector([idleReader]),
      foregroundReader: foregroundReader,
      classifier: CategoryClassifier(CategoryRules.defaults()),
      usageRepository: InMemoryUsageRepository(),
      settings: Settings.defaults(),
      initialUsage: DailyUsage(date: dateOnly(clock)),
      now: () => clock,
    );
    reminderScheduler = ReminderScheduler(settings: Settings.defaults());
    desktopBackdropService = DesktopBackdropService(desktopCaptureReader: FakeDesktopCaptureReader());
    mediaKeySender = _FakeMediaKeySender();
  });

  ReminderViewModel buildViewModel() => ReminderViewModel(
    trackingEngine: trackingEngine,
    reminderScheduler: reminderScheduler,
    desktopBackdropService: desktopBackdropService,
    mediaKeySender: mediaKeySender,
  );

  test('start() sets remaining to the break duration, clamped to at least 1 minute', () {
    final viewModel = buildViewModel();
    addTearDown(viewModel.dispose);

    viewModel.start(breakDurationMinutes: 3, overlayBlurStrength: 0.3);
    expect(viewModel.remaining, const Duration(minutes: 3));

    final zeroViewModel = buildViewModel();
    addTearDown(zeroViewModel.dispose);
    zeroViewModel.start(breakDurationMinutes: 0, overlayBlurStrength: 0.3);
    expect(zeroViewModel.remaining, const Duration(minutes: 1));
  });

  test('start() pauses media only when the current app looks like a media player', () {
    final musicViewModel = buildViewModel();
    addTearDown(musicViewModel.dispose);
    musicViewModel.start(breakDurationMinutes: 3, overlayBlurStrength: 0.3, currentApp: _vlcApp);
    expect(mediaKeySender.playPauseCount, 1);

    final codeViewModel = buildViewModel();
    addTearDown(codeViewModel.dispose);
    codeViewModel.start(breakDurationMinutes: 3, overlayBlurStrength: 0.3, currentApp: _codeApp);
    expect(mediaKeySender.playPauseCount, 1); // unchanged
  });

  test('the countdown ticks down every second and auto-finishes at zero', () {
    fakeAsync((async) {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      viewModel.start(breakDurationMinutes: 1, overlayBlurStrength: 0.3);
      expect(viewModel.remaining, const Duration(minutes: 1));

      async.elapse(const Duration(seconds: 30));
      expect(viewModel.remaining, const Duration(seconds: 30));

      // Reaching zero calls finish('completed') internally, which cancels
      // the timer — elapsing well past that point must not push remaining
      // negative or keep ticking. The very last tick before finishing
      // triggers on `next <= 0` without assigning `next` back to
      // `remaining` first, so it settles one second short of literal zero
      // (matches the original widget-state implementation this was
      // ported from) rather than displaying "0:00" before disappearing.
      async.elapse(const Duration(seconds: 40));
      expect(viewModel.remaining, const Duration(seconds: 1));
    });
  });

  test('finish() stops the countdown and resets the tracking engine\'s continuous streak', () async {
    for (var i = 0; i < 10; i++) {
      clock = clock.add(const Duration(seconds: 1));
      await trackingEngine.tick();
    }
    expect(trackingEngine.currentUsage.continuousActiveSeconds, 10);

    final viewModel = buildViewModel();
    addTearDown(viewModel.dispose);
    viewModel.start(breakDurationMinutes: 3, overlayBlurStrength: 0.3);

    viewModel.finish('closed');
    expect(trackingEngine.currentUsage.continuousActiveSeconds, 0);
    expect(trackingEngine.currentUsage.reminders.single.action, 'closed');
  });
}
