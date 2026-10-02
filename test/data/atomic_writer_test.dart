import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/repositories/atomic_writer.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('atomic_writer_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('creates a new file and its parent directory', () async {
    final path = '${tempDir.path}/nested/dir/file.json';
    await const AtomicWriter().writeString(path, '{"a":1}');

    expect(File(path).readAsStringSync(), '{"a":1}');
  });

  test('replaces an existing file\'s content', () async {
    final path = '${tempDir.path}/file.json';
    await const AtomicWriter().writeString(path, '{"a":1}');
    await const AtomicWriter().writeString(path, '{"a":2}');

    expect(File(path).readAsStringSync(), '{"a":2}');
  });

  test('does not leave a stray temp file behind after a successful write', () async {
    final path = '${tempDir.path}/file.json';
    await const AtomicWriter().writeString(path, '{"a":1}');

    final leftovers = tempDir.listSync(recursive: true).whereType<File>().where(
      (f) => f.path.endsWith('.tmp'),
    );
    expect(leftovers, isEmpty);
  });
}
