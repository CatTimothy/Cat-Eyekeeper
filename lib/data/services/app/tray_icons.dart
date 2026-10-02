import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Generates the tray's icon frames — from a real image file (a single
/// animated `.gif`, decoded frame-by-frame, or a single static image)
/// when it's readable, falling back to a static neutral icon (no bundled
/// art required) otherwise. Colors for the fallback are chosen for
/// contrast against the taskbar (see [useDarkForeground]).
class TrayIconFactory {
  const TrayIconFactory();

  static const defaultFrameCount = 1;
  static const _size = 32;

  /// Real frames from [path], each resized to fit within the 32x32 tray
  /// icon canvas (preserving aspect ratio) and centered on a transparent
  /// background. A `.gif` decodes to every one of its animation frames;
  /// any other image decodes to a single frame. Returns null (caller
  /// falls back to [buildDefaultIcon]) if the file doesn't exist or can't
  /// be read/decoded.
  List<Uint8List>? buildFramesFromImagePath(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;

    final bytes = file.readAsBytesSync();
    final isGif = p.extension(path).toLowerCase() == '.gif';
    img.Image? decoded;
    try {
      decoded = isGif ? img.decodeGif(bytes) : img.decodeImage(bytes);
    } on Object {
      // A malformed/edge-case source file can make package:image's decoder
      // throw instead of returning null (e.g. a GIF that trips a decoder
      // bug) — treat that the same as "can't be decoded" so one bad pack
      // can't take the whole tray (icon, menu, animation) down with it.
      return null;
    }
    if (decoded == null) return null;

    final sourceFrames = decoded.hasAnimation ? decoded.frames : [decoded];
    final frames = <Uint8List>[];
    for (final frame in sourceFrames) {
      // GIF frames decode as palette-indexed images (frame.hasPalette) —
      // on those, writing an individual channel (as _premultiplyAlpha
      // does below) re-quantizes the pixel to the nearest palette entry
      // by that one channel alone, ignoring the others, and can silently
      // jump to a completely different color/alpha (observed: an opaque
      // black pixel's r channel written back to its own value landed on
      // the palette's fully-transparent entry instead). Converting to a
      // direct (non-palette) image first makes every channel independent
      // again, so the premultiply/unpremultiply math below is accurate.
      final direct = frame.hasPalette ? frame.convert(numChannels: 4) : frame;
      final scale = _size / math.max(direct.width, direct.height);
      final resized = _unpremultiplyAlpha(
        img.copyResize(
          _premultiplyAlpha(direct.clone()),
          width: (direct.width * scale).round().clamp(1, _size),
          height: (direct.height * scale).round().clamp(1, _size),
          interpolation: img.Interpolation.average,
        ),
      );

      final canvas = img.Image(width: _size, height: _size, numChannels: 4);
      img.compositeImage(canvas, resized, center: true);
      frames.add(Uint8List.fromList(img.encodePng(canvas)));
    }
    return frames;
  }

  /// `copyResize`'s `Interpolation.average` box-samples R/G/B/A as plain,
  /// separate averages — with straight (non-premultiplied) alpha, a fully
  /// transparent pixel's leftover/garbage color (GIF encoders routinely
  /// leave junk behind the transparent index, often black) bleeds into
  /// neighboring visible pixels, producing a dark fringe/halo around a
  /// transparent GIF's edges once downscaled to the 32x32 tray canvas.
  /// Premultiplying first makes that same box-average formula correct —
  /// [_unpremultiplyAlpha] reverses it afterwards.
  img.Image _premultiplyAlpha(img.Image image) {
    for (final pixel in image) {
      final a = pixel.a / 255.0;
      pixel
        ..r = pixel.r * a
        ..g = pixel.g * a
        ..b = pixel.b * a;
    }
    return image;
  }

  img.Image _unpremultiplyAlpha(img.Image image) {
    for (final pixel in image) {
      final a = pixel.a;
      if (a <= 0) continue;
      final inv = 255.0 / a;
      pixel
        ..r = (pixel.r * inv).clamp(0, 255)
        ..g = (pixel.g * inv).clamp(0, 255)
        ..b = (pixel.b * inv).clamp(0, 255);
    }
    return image;
  }

  /// A single static neutral glyph — the fallback when no pack is
  /// selected, or its art can't be read.
  Uint8List buildDefaultIcon({required bool useDarkForeground}) {
    final color = useDarkForeground ? img.ColorRgba8(25, 25, 25, 255) : img.ColorRgba8(245, 245, 245, 255);
    final image = img.Image(width: _size, height: _size, numChannels: 4);
    img.fillCircle(image, x: (_size / 2).round(), y: (_size / 2).round(), radius: (_size * 0.3).round(), color: color);
    return img.encodePng(image);
  }

  /// Writes a frame set to a fresh temp directory once and returns the
  /// file paths in order — `tray_manager.setIcon()` needs a path, not
  /// raw bytes. [frames] are PNG-encoded (see [buildDefaultIcon] /
  /// [buildFramesFromImagePath]); on Windows they're re-encoded to `.ico`
  /// here, since tray_manager's Windows plugin loads the icon via Win32
  /// `LoadImage(..., IMAGE_ICON, LR_LOADFROMFILE)`, which requires the
  /// classic ICO container format — a raw PNG file makes that call fail
  /// silently, leaving no tray icon at all. Other platforms load PNG
  /// directly, so they're written unchanged.
  Future<List<String>> writeFramesToTempFiles(List<Uint8List> frames) async {
    final dir = await Directory.systemTemp.createTemp('cat_eyekeeper_tray_');
    final extension = Platform.isWindows ? 'ico' : 'png';
    final files = [for (var i = 0; i < frames.length; i++) File(p.join(dir.path, 'frame_$i.$extension'))];
    final bytes = Platform.isWindows ? [for (final frame in frames) _encodeClassicIco(img.decodePng(frame)!)] : frames;
    await Future.wait([for (var i = 0; i < frames.length; i++) files[i].writeAsBytes(bytes[i], flush: true)]);
    return [for (final file in files) file.path];
  }

  /// Hand-rolled classic BMP-format ICO encoder — `package:image`'s
  /// `encodeIco` always PNG-compresses each frame, but PNG compression
  /// inside an ICO container was only ever *required* for entries whose
  /// width/height exceed 255px (ICONDIRENTRY's dimension fields are a
  /// single byte, so 256 is encoded as 0 there and needs PNG to describe
  /// its real size). For small entries like this 32x32 tray icon, the
  /// traditional uncompressed-BMP encoding is the one every Win32 icon
  /// loader is guaranteed to handle — some paths (including, it seems,
  /// whatever `LoadImage(..., IMAGE_ICON, LR_LOADFROMFILE)` does under
  /// the hood here) don't reliably render a PNG-compressed small icon,
  /// which showed up as the tray icon not displaying correctly.
  Uint8List _encodeClassicIco(img.Image image) {
    final width = image.width;
    final height = image.height;
    const iconDirSize = 6;
    const iconDirEntrySize = 16;
    const dibHeaderSize = 40;
    final xorRowBytes = width * 4;
    final xorSize = xorRowBytes * height;
    // 1bpp AND mask, rows padded to a 4-byte boundary — required by the
    // ICO format even though a 32bpp image's own alpha channel already
    // fully describes transparency; left all-zero (opaque) below.
    final andRowBytes = ((width + 31) ~/ 32) * 4;
    final andSize = andRowBytes * height;
    final imageSize = dibHeaderSize + xorSize + andSize;
    final imageOffset = iconDirSize + iconDirEntrySize;

    final buffer = ByteData(imageOffset + imageSize);

    buffer
      ..setUint16(0, 0, Endian.little) // reserved
      ..setUint16(2, 1, Endian.little) // type: icon
      ..setUint16(4, 1, Endian.little); // image count

    buffer
      ..setUint8(6, width >= 256 ? 0 : width)
      ..setUint8(7, height >= 256 ? 0 : height)
      ..setUint8(8, 0) // color count: not palette-based
      ..setUint8(9, 0) // reserved
      ..setUint16(10, 1, Endian.little) // color planes
      ..setUint16(12, 32, Endian.little) // bits per pixel
      ..setUint32(14, imageSize, Endian.little)
      ..setUint32(18, imageOffset, Endian.little);

    buffer
      ..setUint32(imageOffset, dibHeaderSize, Endian.little)
      ..setInt32(imageOffset + 4, width, Endian.little)
      // Doubled: this height covers both the XOR color mask and the AND
      // mask stacked below it, per the classic ICO/CUR DIB convention.
      ..setInt32(imageOffset + 8, height * 2, Endian.little)
      ..setUint16(imageOffset + 12, 1, Endian.little) // planes
      ..setUint16(imageOffset + 14, 32, Endian.little) // bit count
      ..setUint32(imageOffset + 16, 0, Endian.little) // BI_RGB: uncompressed
      ..setUint32(imageOffset + 20, xorSize, Endian.little);

    // XOR mask: bottom-up rows, packed BGRA — the AND mask after it is
    // left zeroed by ByteData's own zero-initialization.
    var offset = imageOffset + dibHeaderSize;
    for (var y = height - 1; y >= 0; y--) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        buffer
          ..setUint8(offset, pixel.b.toInt())
          ..setUint8(offset + 1, pixel.g.toInt())
          ..setUint8(offset + 2, pixel.r.toInt())
          ..setUint8(offset + 3, pixel.a.toInt());
        offset += 4;
      }
    }

    return buffer.buffer.asUint8List();
  }
}
