import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:cat_eyekeeper/data/services/app/tray_icons.dart';

void main() {
  test('buildDefaultIcon produces a single valid 32x32 PNG', () {
    final frame = const TrayIconFactory().buildDefaultIcon(useDarkForeground: false);

    final decoded = img.decodePng(frame);
    expect(decoded, isNotNull);
    expect(decoded!.width, 32);
    expect(decoded.height, 32);
  });

  test('writeFramesToTempFiles writes one file per frame, readable in the platform tray icon format', () async {
    final frame = const TrayIconFactory().buildDefaultIcon(useDarkForeground: true);
    final paths = await const TrayIconFactory().writeFramesToTempFiles([frame]);
    addTearDown(() {
      for (final path in paths) {
        final parent = File(path).parent;
        if (parent.existsSync()) parent.deleteSync(recursive: true);
      }
    });

    expect(paths, hasLength(1));
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue);
      // Windows tray_manager loads icons via Win32 LoadImage(IMAGE_ICON),
      // which requires the classic .ico container, not raw PNG — see
      // writeFramesToTempFiles' doc comment.
      final decoded = Platform.isWindows
          ? img.decodeIco(File(path).readAsBytesSync())
          : img.decodePng(File(path).readAsBytesSync());
      expect(decoded, isNotNull);
      expect(path, endsWith(Platform.isWindows ? '.ico' : '.png'));
    }
  });

  test(
    'writeFramesToTempFiles round-trips exact pixel colors and alpha through the classic ICO encoding',
    () async {
      // Distinct per-pixel colors/alpha (including full transparency and
      // partial alpha) so row-order, channel-order (BGRA vs RGBA), or
      // alpha-handling bugs in the hand-rolled encoder would show up as a
      // mismatch somewhere in the grid, not just an overall tint.
      final source = img.Image(width: 4, height: 4, numChannels: 4);
      source
        ..setPixelRgba(0, 0, 255, 0, 0, 255)
        ..setPixelRgba(1, 0, 0, 255, 0, 128)
        ..setPixelRgba(2, 0, 0, 0, 255, 0)
        ..setPixelRgba(3, 0, 10, 20, 30, 200);
      for (var y = 1; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          source.setPixelRgba(x, y, x * 10, y * 10, 100, 255);
        }
      }
      final framePng = Uint8List.fromList(img.encodePng(source));

      final paths = await const TrayIconFactory().writeFramesToTempFiles([framePng]);
      addTearDown(() {
        for (final path in paths) {
          final parent = File(path).parent;
          if (parent.existsSync()) parent.deleteSync(recursive: true);
        }
      });

      final decoded = img.decodeIco(File(paths.single).readAsBytesSync())!;
      expect(decoded.width, 4);
      expect(decoded.height, 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final expected = source.getPixel(x, y);
          final actual = decoded.getPixel(x, y);
          expect(actual.r, expected.r, reason: 'r mismatch at ($x, $y)');
          expect(actual.g, expected.g, reason: 'g mismatch at ($x, $y)');
          expect(actual.b, expected.b, reason: 'b mismatch at ($x, $y)');
          expect(actual.a, expected.a, reason: 'a mismatch at ($x, $y)');
        }
      }
    },
    skip: Platform.isWindows ? false : 'ICO encoding only happens on Windows',
  );

  group('buildFramesFromImagePath', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tray_icons_pack_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    String writeFakeImage({required int width, required int height, String fileName = 'icon.png'}) {
      final image = img.Image(width: width, height: height, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));
      final path = p.join(tempDir.path, fileName);
      File(path).writeAsBytesSync(img.encodePng(image));
      return path;
    }

    test('resizes a larger square image down to fit the 32x32 tray canvas', () {
      final imagePath = writeFakeImage(width: 1254, height: 1254);

      final frames = const TrayIconFactory().buildFramesFromImagePath(imagePath);

      expect(frames, hasLength(1));
      final decoded = img.decodePng(frames!.single);
      expect(decoded!.width, 32);
      expect(decoded.height, 32);
    });

    test('leaves an already tray-icon-sized image as-is', () {
      final imagePath = writeFakeImage(width: 32, height: 32);

      final frames = const TrayIconFactory().buildFramesFromImagePath(imagePath);

      expect(frames, hasLength(1));
      final decoded = img.decodePng(frames!.single);
      expect(decoded!.width, 32);
      expect(decoded.height, 32);
    });

    test('decodes every frame of an animated gif', () {
      final gifBytes = img.encodeGif(
        img.Image(width: 8, height: 8, numChannels: 4)
          ..addFrame(img.Image(width: 8, height: 8, numChannels: 4))
          ..addFrame(img.Image(width: 8, height: 8, numChannels: 4)),
      );
      final path = p.join(tempDir.path, 'anim.gif');
      File(path).writeAsBytesSync(gifBytes);

      final frames = const TrayIconFactory().buildFramesFromImagePath(path);

      expect(frames, hasLength(3));
    });

    test('does not bleed a transparent pixel\'s leftover color into visible edges when downscaling', () {
      // Half opaque red, half fully transparent but with leftover green
      // "garbage" color data (as real GIF encoders routinely leave behind
      // a transparent index) — a naive box-average downscale would blend
      // that invisible green into the red half's edge pixels.
      // The split sits at x=253, not the exact midpoint (250) of this
      // 500px source — an even split maps to a clean output-pixel
      // boundary regardless of source size (always exactly half of the
      // 32px tray canvas), landing on it instead of straddling it.
      const size = 500;
      final image = img.Image(width: size, height: size, numChannels: 4);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (x < 253) {
            image.setPixelRgba(x, y, 255, 0, 0, 255);
          } else {
            image.setPixelRgba(x, y, 0, 255, 0, 0);
          }
        }
      }
      final path = p.join(tempDir.path, 'fringe.png');
      File(path).writeAsBytesSync(img.encodePng(image));

      final frames = const TrayIconFactory().buildFramesFromImagePath(path);
      final decoded = img.decodePng(frames!.single)!;

      for (final pixel in decoded) {
        if (pixel.a > 0) {
          expect(
            pixel.g,
            lessThan(5),
            reason: 'pixel at (${pixel.x}, ${pixel.y}) picked up green from a fully-transparent neighbor',
          );
        }
      }
    });

    test('returns null when the image file is missing', () {
      final path = p.join(tempDir.path, 'does_not_exist.png');

      expect(const TrayIconFactory().buildFramesFromImagePath(path), isNull);
    });

    test('decodes every frame of the bundled Cat pack gif (regression: cropped first-frame gifs crash package:image)', () {
      // package:image's GifDecoder sizes its merge canvas from the FIRST
      // frame's own decoded dimensions rather than the logical screen size
      // — a gif whose first frame is a cropped sub-rectangle (a common
      // encoder optimization) makes later, larger frames write out of
      // bounds and throw. assets/bundled_packs/tray_icon/star_cat/image.gif
      // must stay encoded with a full-canvas first frame to avoid that crash.
      final path = p.join(
        Directory.current.path,
        'assets',
        'bundled_packs',
        'tray_icon',
        'star_cat',
        'image.gif',
      );
      expect(File(path).existsSync(), isTrue, reason: 'bundled Cat tray icon asset is missing');

      final frames = const TrayIconFactory().buildFramesFromImagePath(path);

      expect(frames, isNotNull);
      expect(frames!.length, greaterThan(1));
      for (final frame in frames) {
        final decoded = img.decodePng(frame)!;
        final hasOpaquePixel = decoded.any((pixel) => pixel.a > 200);
        expect(hasOpaquePixel, isTrue, reason: 'frame decoded as fully transparent — the icon would be invisible');
      }
    });

    test(
      'does not blank out a palette-indexed (gif-sourced) image when premultiplying alpha',
      () {
        // Regression: GIF frames decode as palette-indexed images
        // (Image.hasPalette). Writing an individual channel on a palette
        // pixel (as _premultiplyAlpha does) re-quantizes it to the
        // nearest palette entry by that one channel alone — an opaque
        // pixel whose red channel gets written back to its own value can
        // jump to a completely different palette entry (observed: landed
        // on the fully-transparent one), silently blanking the whole
        // icon. Built directly via quantize (not a real gif file) so this
        // guards the underlying mechanism regardless of any bundled asset.
        final source = img.Image(width: 64, height: 64, numChannels: 4);
        img.fill(source, color: img.ColorRgba8(0, 255, 0, 0));
        img.fillRect(
          source,
          x1: 16,
          y1: 16,
          x2: 48,
          y2: 48,
          color: img.ColorRgba8(0, 0, 0, 255),
        );
        final paletted = img.quantize(source, numberOfColors: 2);
        expect(paletted.hasPalette, isTrue);

        final path = p.join(tempDir.path, 'paletted.gif');
        File(path).writeAsBytesSync(img.encodeGif(paletted));

        final frames = const TrayIconFactory().buildFramesFromImagePath(path);

        expect(frames, isNotNull);
        final decoded = img.decodePng(frames!.single)!;
        final hasOpaquePixel = decoded.any((pixel) => pixel.a > 200);
        expect(hasOpaquePixel, isTrue, reason: 'the opaque square was blanked out during premultiply/unpremultiply');
      },
    );
  });
}
