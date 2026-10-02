/// Samples system-wide CPU utilization. See
/// windows/win_cpu_reader.dart and linux/proc_cpu_reader.dart.
abstract class CpuReader {
  /// A usage percentage in [0, 100], or null if a sample isn't available
  /// yet (e.g. the very first call only seeds a delta baseline).
  double? sampleUsagePercent();
}
