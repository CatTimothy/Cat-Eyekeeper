import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/cpu_monitor.dart';
import 'package:cat_eyekeeper/data/services/platform/cpu_reader.dart';

class _FakeCpuReader implements CpuReader {
  _FakeCpuReader(this.values);
  final List<double?> values;
  int _index = 0;

  @override
  double? sampleUsagePercent() {
    final value = _index < values.length ? values[_index] : values.last;
    _index++;
    return value;
  }
}

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  test('publishes the average of the last 5 samples every 5th capture', () async {
    final reader = _FakeCpuReader([10, 20, 30, 40, 50]);
    final monitor = CpuMonitor(reader: reader);
    final published = <double>[];
    monitor.samples.listen((s) => published.add(s.usagePercent));

    for (var i = 0; i < 5; i++) {
      monitor.capture();
    }
    await _flushMicrotasks();

    expect(published, [30]); // average of 10,20,30,40,50
  });

  test('does not publish before 5 captures have accumulated', () async {
    final reader = _FakeCpuReader([10, 20, 30]);
    final monitor = CpuMonitor(reader: reader);
    var publishCount = 0;
    monitor.samples.listen((_) => publishCount++);

    for (var i = 0; i < 3; i++) {
      monitor.capture();
    }
    await _flushMicrotasks();

    expect(publishCount, 0);
  });

  test('a null sample (reader not ready yet) is skipped without crashing', () async {
    final reader = _FakeCpuReader([null, null, 10, 20, 30, 40, 50]);
    final monitor = CpuMonitor(reader: reader);
    final published = <double>[];
    monitor.samples.listen((s) => published.add(s.usagePercent));

    for (var i = 0; i < 7; i++) {
      monitor.capture();
    }
    await _flushMicrotasks();

    expect(published, [30]);
  });
}
