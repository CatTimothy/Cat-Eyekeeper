import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../platform/desktop_capture_reader.dart';

/// One monitor's blurred backdrop, ready to draw behind the reminder
/// overlay at [bounds] (see ui/reminder/reminder_overlay.dart).
class MonitorBackdrop {
  const MonitorBackdrop({required this.bounds, required this.blurredPngBytes});

  final MonitorBounds bounds;
  final Uint8List blurredPngBytes;
}

/// Builds the reminder overlay's blurred-desktop backdrop — a real
/// screenshot of whatever is behind the app, downsampled and
/// Gaussian-blurred so a transparent reminder image/video reads correctly
/// on every theme (there's no native window blur-behind anymore, see the
/// removed Liquid Glass theme). Captured per monitor (see
/// platform/desktop_capture_reader.dart) so the reminder can lock every
/// connected monitor with its own correct backdrop, not one image
/// stretched across all of them. Windows-only for now (see
/// platform/linux/null_desktop_capture_reader.dart); callers fall back to
/// a flat background wherever [captureBlurredMonitors] returns an empty
/// list.
class DesktopBackdropService {
  DesktopBackdropService({required this.desktopCaptureReader});

  final DesktopCaptureReader desktopCaptureReader;

  /// Downsampled before blurring — blur cost scales with pixel count, and
  /// the result is shown at [BoxFit.cover] anyway, so the resolution loss
  /// is invisible under a strong blur.
  static const _downsampleWidth = 960;

  Future<List<MonitorBackdrop>> captureBlurredMonitors({required double blurStrength}) async {
    final captures = desktopCaptureReader.captureAllMonitors();
    if (captures.isEmpty) return [];

    final radius = (blurStrength * 40).round().clamp(1, 60);
    final backdrops = <MonitorBackdrop>[];
    for (final capture in captures) {
      var image = img.decodeImage(capture.pngBytes);
      if (image == null) continue;
      if (image.width > _downsampleWidth) {
        image = img.copyResize(image, width: _downsampleWidth);
      }
      image = img.gaussianBlur(image, radius: radius);
      backdrops.add(MonitorBackdrop(bounds: capture.bounds, blurredPngBytes: Uint8List.fromList(img.encodePng(image))));
    }
    return backdrops;
  }
}
