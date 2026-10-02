/// Frame interval used before any CPU sample has arrived yet.
const Duration initialTrayTickInterval = Duration(milliseconds: 200);

const Duration _pausedTrayTickInterval = Duration(milliseconds: 900);
const double _referenceIntervalMs = 500;

/// How fast the tray animation should advance: faster under higher CPU
/// load, frozen to a slow cadence while tracking is paused.
Duration trayTickInterval(double usagePercent, {bool isPaused = false}) {
  if (isPaused) return _pausedTrayTickInterval;
  final millis = (_referenceIntervalMs / traySpeedMultiplier(usagePercent)).round();
  return Duration(milliseconds: millis);
}

/// 1x at idle CPU, scaling up to 20x at 100% CPU.
double traySpeedMultiplier(double usagePercent) {
  final load = usagePercent.clamp(0, 100);
  final scaled = load / 5;
  return scaled < 1 ? 1 : scaled;
}
