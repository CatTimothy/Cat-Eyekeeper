import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../cpu_reader.dart';

/// Samples CPU usage from `GetSystemTimes`' idle/kernel/user tick counters,
/// diffing against the previous sample (kernel time already includes idle
/// time on Windows, so `busy = (kernel+user - idle) / (kernel+user)`).
/// The first call only seeds the baseline and returns null.
class WinCpuReader implements CpuReader {
  int? _lastIdle;
  int? _lastKernel;
  int? _lastUser;

  @override
  double? sampleUsagePercent() {
    final idle = calloc<FILETIME>();
    final kernel = calloc<FILETIME>();
    final user = calloc<FILETIME>();
    try {
      if (GetSystemTimes(idle, kernel, user) == 0) return null;

      final idleTicks = _toTicks(idle.ref);
      final kernelTicks = _toTicks(kernel.ref);
      final userTicks = _toTicks(user.ref);

      final lastIdle = _lastIdle;
      final lastKernel = _lastKernel;
      final lastUser = _lastUser;
      _lastIdle = idleTicks;
      _lastKernel = kernelTicks;
      _lastUser = userTicks;

      if (lastIdle == null || lastKernel == null || lastUser == null) return null;

      final idleDelta = idleTicks - lastIdle;
      final totalDelta = (kernelTicks - lastKernel) + (userTicks - lastUser);
      if (totalDelta <= 0) return null;

      final busyPercent = (totalDelta - idleDelta) * 100 / totalDelta;
      return busyPercent.clamp(0, 100);
    } finally {
      calloc.free(idle);
      calloc.free(kernel);
      calloc.free(user);
    }
  }

  int _toTicks(FILETIME ft) => (ft.dwHighDateTime << 32) | ft.dwLowDateTime;
}
