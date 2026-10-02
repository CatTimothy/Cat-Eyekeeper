import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/cpu_load.dart';
import 'package:cat_eyekeeper/domain/models/cpu.dart';

void main() {
  test('classifyCpuLoad buckets at the documented thresholds', () {
    expect(classifyCpuLoad(0), CpuLoad.low);
    expect(classifyCpuLoad(19.99), CpuLoad.low);
    expect(classifyCpuLoad(20), CpuLoad.normal);
    expect(classifyCpuLoad(59.99), CpuLoad.normal);
    expect(classifyCpuLoad(60), CpuLoad.high);
    expect(classifyCpuLoad(84.99), CpuLoad.high);
    expect(classifyCpuLoad(85), CpuLoad.veryHigh);
    expect(classifyCpuLoad(100), CpuLoad.veryHigh);
  });
}
