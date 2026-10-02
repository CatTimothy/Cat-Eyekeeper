import 'dart:async';

import 'package:flutter/foundation.dart';

/// Base for every feature ViewModel that subscribes to a stream (usage
/// snapshots, CPU samples, reminder-due events, window-shell state, ...).
/// Riverpod's providers got subscription teardown for free via
/// `ref.onDispose`/autoDispose; a plain [ChangeNotifier] has no equivalent,
/// so subclasses register their subscriptions here instead of managing
/// cancellation by hand at every call site.
abstract class BaseViewModel extends ChangeNotifier {
  final _subscriptions = <StreamSubscription<void>>[];
  bool _disposed = false;

  /// Registers [subscription] to be cancelled automatically in [dispose].
  void addSubscription(StreamSubscription<void> subscription) => _subscriptions.add(subscription);

  /// Use instead of [notifyListeners] inside async/stream callbacks that
  /// may still fire after the View (and this ViewModel) has already been
  /// torn down — calling the real [notifyListeners] post-dispose throws.
  void safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
