import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

import '../app_icon_reader.dart';

/// Extracts an executable's associated icon via the shell (the same icon
/// Explorer shows) and converts the classic HICON -> DIB -> PNG, the
/// standard technique for this API.
class WinAppIconReader implements AppIconReader {
  // Reading + converting an icon touches the shell and GDI; cache per exe
  // path since it never changes for a given executable.
  final Map<String, Uint8List?> _cache = {};

  @override
  Uint8List? read(String executablePath) {
    if (executablePath.isEmpty) return null;
    return _cache.putIfAbsent(executablePath, () => _extractIconPng(executablePath));
  }

  Uint8List? _extractIconPng(String executablePath) {
    final pathPtr = executablePath.toNativeUtf16();
    final infoPtr = calloc<SHFILEINFO>();
    try {
      final result = SHGetFileInfo(pathPtr, 0, infoPtr, sizeOf<SHFILEINFO>(), SHGFI_ICON | SHGFI_LARGEICON);
      if (result == 0) return null;
      final hIcon = infoPtr.ref.hIcon;
      if (hIcon == 0) return null;
      try {
        return _iconToPng(hIcon);
      } finally {
        DestroyIcon(hIcon);
      }
    } on Object {
      return null;
    } finally {
      calloc.free(pathPtr);
      calloc.free(infoPtr);
    }
  }

  Uint8List? _iconToPng(int hIcon) {
    final iconInfoPtr = calloc<ICONINFO>();
    try {
      if (GetIconInfo(hIcon, iconInfoPtr) == 0) return null;
      final hbmColor = iconInfoPtr.ref.hbmColor;
      final hbmMask = iconInfoPtr.ref.hbmMask;
      try {
        if (hbmColor == 0) return null;
        return _bitmapToPng(hbmColor);
      } finally {
        if (hbmColor != 0) DeleteObject(hbmColor);
        if (hbmMask != 0) DeleteObject(hbmMask);
      }
    } finally {
      calloc.free(iconInfoPtr);
    }
  }

  Uint8List? _bitmapToPng(int hbmColor) {
    final bitmapPtr = calloc<BITMAP>();
    final bitmapInfoPtr = calloc<BITMAPINFO>();
    final hdc = GetDC(0);
    Pointer<Uint8>? pixelsPtr;
    try {
      if (GetObject(hbmColor, sizeOf<BITMAP>(), bitmapPtr) == 0) return null;
      final width = bitmapPtr.ref.bmWidth;
      final height = bitmapPtr.ref.bmHeight;
      if (width <= 0 || height <= 0) return null;

      bitmapInfoPtr.ref.bmiHeader
        ..biSize = sizeOf<BITMAPINFOHEADER>()
        ..biWidth = width
        ..biHeight = -height // negative: top-down row order, matches our read loop below
        ..biPlanes = 1
        ..biBitCount = 32
        ..biCompression = BI_RGB;

      final byteCount = width * height * 4;
      pixelsPtr = calloc<Uint8>(byteCount);
      final scanLines = GetDIBits(hdc, hbmColor, 0, height, pixelsPtr.cast(), bitmapInfoPtr, DIB_RGB_COLORS);
      if (scanLines == 0) return null;

      // 32bpp DIBs are packed BGRA; per-pixel alpha may be entirely zero
      // for older icons that only carry an AND mask instead of real
      // alpha — treat that as fully opaque rather than rendering an
      // invisible icon.
      final bgra = pixelsPtr.asTypedList(byteCount);
      var hasAlpha = false;
      for (var i = 3; i < byteCount; i += 4) {
        if (bgra[i] != 0) {
          hasAlpha = true;
          break;
        }
      }
      final image = img.Image(width: width, height: height, numChannels: 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final o = (y * width + x) * 4;
          final a = hasAlpha ? bgra[o + 3] : 255;
          image.setPixelRgba(x, y, bgra[o + 2], bgra[o + 1], bgra[o], a);
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    } finally {
      calloc.free(bitmapPtr);
      calloc.free(bitmapInfoPtr);
      if (pixelsPtr != null) calloc.free(pixelsPtr);
      if (hdc != 0) ReleaseDC(0, hdc);
    }
  }
}
