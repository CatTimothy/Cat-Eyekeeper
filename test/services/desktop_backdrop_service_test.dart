import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:cat_eyekeeper/data/services/platform/desktop_capture_reader.dart';
import 'package:cat_eyekeeper/data/services/app/desktop_backdrop_service.dart';

import '../platform/fakes/fake_desktop_capture_reader.dart';

Uint8List _solidColorPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 130, 140));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('DesktopBackdropService.captureBlurredMonitors', () {
    test('returns an empty list when the reader has no captures', () async {
      final service = DesktopBackdropService(desktopCaptureReader: FakeDesktopCaptureReader());
      final backdrops = await service.captureBlurredMonitors(blurStrength: 0.5);
      expect(backdrops, isEmpty);
    });

    test('returns one blurred, decodable backdrop per monitor, preserving bounds', () async {
      final captures = [
        MonitorCapture(bounds: const MonitorBounds(x: 0, y: 0, width: 100, height: 80), pngBytes: _solidColorPng(100, 80)),
        MonitorCapture(
          bounds: const MonitorBounds(x: -100, y: 0, width: 100, height: 80),
          pngBytes: _solidColorPng(100, 80),
        ),
      ];
      final service = DesktopBackdropService(
        desktopCaptureReader: FakeDesktopCaptureReader(captures: captures),
      );

      final backdrops = await service.captureBlurredMonitors(blurStrength: 0.5);

      expect(backdrops, hasLength(2));
      expect(backdrops[0].bounds.x, 0);
      expect(backdrops[1].bounds.x, -100);
      for (final backdrop in backdrops) {
        expect(img.decodeImage(backdrop.blurredPngBytes), isNotNull);
      }
    });
  });
}
