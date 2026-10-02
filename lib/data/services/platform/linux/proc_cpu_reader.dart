import 'dart:io';

import '../cpu_reader.dart';

/// Samples CPU usage from `/proc/stat`'s aggregate `cpu` line, diffing
/// against the previous sample. `/proc/stat` reports cumulative jiffies
/// since boot as: user nice system idle iowait irq softirq [steal ...] —
/// busy = everything except idle+iowait. The first call only seeds the
/// baseline and returns null.
class ProcCpuReader implements CpuReader {
  int? _lastIdle;
  int? _lastTotal;

  @override
  double? sampleUsagePercent() {
    final fields = _readCpuLineFields();
    if (fields == null) return null;

    final idle = fields[3] + (fields.length > 4 ? fields[4] : 0); // idle + iowait
    final total = fields.fold<int>(0, (sum, value) => sum + value);

    final lastIdle = _lastIdle;
    final lastTotal = _lastTotal;
    _lastIdle = idle;
    _lastTotal = total;

    if (lastIdle == null || lastTotal == null) return null;

    final idleDelta = idle - lastIdle;
    final totalDelta = total - lastTotal;
    if (totalDelta <= 0) return null;

    final busyPercent = (totalDelta - idleDelta) * 100 / totalDelta;
    return busyPercent.clamp(0, 100);
  }

  List<int>? _readCpuLineFields() {
    try {
      final firstLine = File('/proc/stat').readAsLinesSync().first;
      if (!firstLine.startsWith('cpu ')) return null;
      final fields = firstLine
          .substring(4)
          .trim()
          .split(RegExp(r'\s+'))
          .map(int.parse)
          .toList();
      return fields.length >= 4 ? fields : null;
    } on Object {
      return null;
    }
  }
}
