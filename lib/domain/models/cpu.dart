import 'package:freezed_annotation/freezed_annotation.dart';

part 'cpu.freezed.dart';

/// CPU load bucket driving tray-icon animation speed (see
/// core/tray_speed.dart) — not persisted to disk.
enum CpuLoad { low, normal, high, veryHigh }

const Map<CpuLoad, String> _cpuLoadJsonValues = {
  CpuLoad.low: 'low',
  CpuLoad.normal: 'normal',
  CpuLoad.high: 'high',
  CpuLoad.veryHigh: 'very_high',
};

String cpuLoadToJson(CpuLoad load) => _cpuLoadJsonValues[load]!;

/// One CPU utilization reading, produced by a platform/*_cpu_reader.dart
/// implementation and classified via core/cpu_load.dart's classifyCpuLoad().
@freezed
abstract class CpuSample with _$CpuSample {
  const factory CpuSample({required double usagePercent, required CpuLoad loadLevel, required DateTime updatedAt}) =
      _CpuSample;
}
