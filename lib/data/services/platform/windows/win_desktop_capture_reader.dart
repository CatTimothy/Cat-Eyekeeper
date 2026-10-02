import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

import '../desktop_capture_reader.dart';

/// Filled in by [_monitorEnumProc] while [EnumDisplayMonitors] runs, then
/// drained by the caller. `Pointer.fromFunction` callbacks can't close
/// over local state, so this has to be a top-level/static accumulator —
/// safe because `EnumDisplayMonitors` calls back synchronously, entirely
/// within the extent of a single `_enumerateMonitors` call.
final List<MonitorBounds> _enumeratedMonitors = [];

int _monitorEnumProc(int hMonitor, int hdcMonitor, Pointer lprcMonitor, int dwData) {
  final rect = lprcMonitor.cast<RECT>().ref;
  _enumeratedMonitors.add(
    MonitorBounds(x: rect.left, y: rect.top, width: rect.right - rect.left, height: rect.bottom - rect.top),
  );
  return 1; // continue enumeration
}

/// Captures each monitor separately via classic GDI `BitBlt`, the same
/// DC/DIB technique already used in windows/win_app_icon_reader.dart for
/// per-exe icons, just targeting a monitor's own screen rectangle instead
/// of an `HICON`.
class WinDesktopCaptureReader implements DesktopCaptureReader {
  @override
  List<MonitorBounds> listMonitors() {
    try {
      return _enumerateMonitors();
    } on Object {
      return [];
    }
  }

  List<MonitorBounds> _enumerateMonitors() {
    _enumeratedMonitors.clear();
    final callback = Pointer.fromFunction<MONITORENUMPROC>(_monitorEnumProc, 0);
    EnumDisplayMonitors(0, nullptr, callback, 0);
    final monitors = List<MonitorBounds>.of(_enumeratedMonitors);
    _enumeratedMonitors.clear();
    return monitors;
  }

  @override
  List<MonitorCapture> captureAllMonitors() {
    final monitors = listMonitors();
    if (monitors.isEmpty) return [];

    final hdcScreen = GetDC(0);
    if (hdcScreen == 0) return [];
    try {
      final captures = <MonitorCapture>[];
      for (final bounds in monitors) {
        if (bounds.width <= 0 || bounds.height <= 0) continue;
        final png = _captureRegion(hdcScreen, bounds.x, bounds.y, bounds.width, bounds.height);
        if (png != null) captures.add(MonitorCapture(bounds: bounds, pngBytes: png));
      }
      return captures;
    } finally {
      ReleaseDC(0, hdcScreen);
    }
  }

  Uint8List? _captureRegion(int hdcScreen, int x, int y, int width, int height) {
    var hdcMem = 0;
    var hBitmap = 0;
    final bitmapInfoPtr = calloc<BITMAPINFO>();
    Pointer<Uint8>? pixelsPtr;
    try {
      hdcMem = CreateCompatibleDC(hdcScreen);
      if (hdcMem == 0) return null;
      hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);
      if (hBitmap == 0) return null;
      final previousObject = SelectObject(hdcMem, hBitmap);

      final blitOk = BitBlt(hdcMem, 0, 0, width, height, hdcScreen, x, y, SRCCOPY);
      SelectObject(hdcMem, previousObject);
      if (blitOk == 0) return null;

      bitmapInfoPtr.ref.bmiHeader
        ..biSize = sizeOf<BITMAPINFOHEADER>()
        ..biWidth = width
        ..biHeight = -height // negative: top-down row order, matches our read loop below
        ..biPlanes = 1
        ..biBitCount = 32
        ..biCompression = BI_RGB;

      final byteCount = width * height * 4;
      pixelsPtr = calloc<Uint8>(byteCount);
      final scanLines = GetDIBits(hdcScreen, hBitmap, 0, height, pixelsPtr.cast(), bitmapInfoPtr, DIB_RGB_COLORS);
      if (scanLines == 0) return null;

      // 32bpp DIBs are packed BGRA; a screen capture has no real alpha
      // channel, so treat every pixel as fully opaque.
      final bgra = pixelsPtr.asTypedList(byteCount);
      final image = img.Image(width: width, height: height, numChannels: 3);
      for (var py = 0; py < height; py++) {
        for (var px = 0; px < width; px++) {
          final o = (py * width + px) * 4;
          image.setPixelRgb(px, py, bgra[o + 2], bgra[o + 1], bgra[o]);
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    } on Object {
      return null;
    } finally {
      if (hBitmap != 0) DeleteObject(hBitmap);
      if (hdcMem != 0) DeleteDC(hdcMem);
      calloc.free(bitmapInfoPtr);
      if (pixelsPtr != null) calloc.free(pixelsPtr);
    }
  }
}
