import 'dart:async';
import 'dart:collection';

import '../models/cpu.dart';
import '../../data/services/platform/cpu_reader.dart';
import 'cpu_load.dart';

/// Samples CPU usage every second via a [CpuReader], smooths over the
/// last 5 raw samples, and publishes a [CpuSample] roughly every 5
/// seconds — the tray animation (core/tray_speed.dart) only needs a
/// slow-moving average, not per-second jitter.
class CpuMonitor {
  CpuMonitor({required CpuReader reader, DateTime Function()? now}) : _reader = reader, _now = now ?? DateTime.now;

  static const _sampleWindowSize = 5;
  static const _publishWindowSize = 5;

  final CpuReader _reader;
  final DateTime Function() _now;
  final _samples = Queue<double>();
  int _publishCounter = 0;

  Timer? _timer;
  final _controller = StreamController<CpuSample>.broadcast();

  Stream<CpuSample> get samples => _controller.stream;
  CpuSample? current;

  void start() {
    capture();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => capture());
  }

  /// Runs one sampling step. Public so tests can drive it deterministically
  /// without a real timer.
  void capture() {
    final raw = _reader.sampleUsagePercent();
    if (raw == null) return;

    _samples.add(raw);
    while (_samples.length > _sampleWindowSize) {
      _samples.removeFirst();
    }

    _publishCounter++;
    if (_publishCounter < _publishWindowSize) return;
    _publishCounter = 0;

    final average = _samples.reduce((a, b) => a + b) / _samples.length;
    final sample = CpuSample(usagePercent: average, loadLevel: classifyCpuLoad(average), updatedAt: _now());
    current = sample;
    _controller.add(sample);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
