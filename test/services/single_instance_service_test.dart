import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/data/services/app/single_instance_service.dart';

/// Binds an ephemeral port and immediately releases it, so a pair of
/// [SingleInstanceService]s can share a real, currently-free port number
/// instead of a hardcoded one that might collide with something else
/// running on the test machine.
Future<int> _freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  return port;
}

void main() {
  test('claim() succeeds and binds the port when nothing else holds it', () async {
    final service = SingleInstanceService(port: 0);
    addTearDown(service.dispose);

    expect(await service.claim(), isTrue);
  });

  test('claim() fails once another instance already holds the port', () async {
    final port = await _freePort();
    // A no-op onPinged: this test only cares about the boolean return
    // values, and the real default calls window_manager, which needs a
    // Flutter binding this plain `test()` doesn't have.
    final primary = SingleInstanceService(port: port, onPinged: () async {});
    addTearDown(primary.dispose);
    expect(await primary.claim(), isTrue);

    final secondary = SingleInstanceService(port: port);
    addTearDown(secondary.dispose);
    expect(await secondary.claim(), isFalse);
  });

  test('a failed claim pings the primary, which runs its onPinged callback', () async {
    final port = await _freePort();
    final pinged = Completer<void>();
    final primary = SingleInstanceService(port: port, onPinged: () async => pinged.complete());
    addTearDown(primary.dispose);
    expect(await primary.claim(), isTrue);

    final secondary = SingleInstanceService(port: port);
    addTearDown(secondary.dispose);
    expect(await secondary.claim(), isFalse);

    await pinged.future.timeout(const Duration(seconds: 2));
  });

  test('dispose() releases the port so a later claim on it can succeed again', () async {
    final port = await _freePort();
    final first = SingleInstanceService(port: port, onPinged: () async {});
    expect(await first.claim(), isTrue);
    await first.dispose();

    final second = SingleInstanceService(port: port);
    addTearDown(second.dispose);
    expect(await second.claim(), isTrue);
  });
}
