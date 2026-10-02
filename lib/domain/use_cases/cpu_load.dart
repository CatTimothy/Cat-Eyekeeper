import '../models/cpu.dart';

/// Buckets a CPU usage percentage into a [CpuLoad] level.
CpuLoad classifyCpuLoad(double usagePercent) {
  if (usagePercent < 20) return CpuLoad.low;
  if (usagePercent < 60) return CpuLoad.normal;
  if (usagePercent < 85) return CpuLoad.high;
  return CpuLoad.veryHigh;
}
