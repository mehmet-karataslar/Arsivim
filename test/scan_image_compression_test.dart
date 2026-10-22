import 'dart:typed_data';
import 'package:arsiv_uygulamasi/services/scan_image_compression.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'Photographed text stays at its resolution and becomes a smaller JPEG',
    () {
      final page = img.Image(width: 1200, height: 1700);
      // Deterministic paper texture approximates camera noise, unlike a flat PNG.
      var noise = 17;
      for (final pixel in page) {
        noise = (noise * 1664525 + 1013904223) & 0xffffffff;
        final tone = 230 + ((noise >> 16) % 26);
        pixel.setRgb(tone, tone, tone);
      }
      for (var y = 40; y < 1650; y += 45) {
        img.drawString(
          page,
          'Belge 2026 - 0123456789 ABC abc',
          font: img.arial24,
          x: 40,
          y: y,
          color: img.ColorRgb8(20, 20, 20),
        );
      }
      final source = img.encodePng(page);
      final compressed = ScanImageCompression.compress(source);
      final decoded = img.decodeJpg(compressed)!;
      expect((decoded.width, decoded.height), (1200, 1700));
      expect(compressed.length, lessThan(source.length * 0.5));
      // Fine dark strokes retain contrast after compression.
      var dark = 0, preserved = 0;
      for (final pixel in page) {
        if (pixel.r < 40) {
          dark++;
          if (decoded.getPixel(pixel.x, pixel.y).r < 80) preserved++;
        }
      }
      expect(dark, greaterThan(1000));
      expect(preserved / dark, greaterThan(0.99));
    },
  );
  test('Large photos keep aspect ratio and an A4 300 dpi long edge', () {
    final page = img.Image(width: 3600, height: 1800);
    img.fill(page, color: img.ColorRgb8(245, 245, 245));
    final result =
        img.decodeJpg(ScanImageCompression.compress(img.encodePng(page)))!;
    expect((result.width, result.height), (3508, 1754));
  });
  test('Transparent paper is white and small images are never upscaled', () {
    final page = img.Image(width: 80, height: 120, numChannels: 4);
    img.fillRect(
      page,
      x1: 20,
      y1: 20,
      x2: 60,
      y2: 50,
      color: img.ColorRgba8(0, 0, 0, 255),
    );
    final result =
        img.decodeJpg(ScanImageCompression.compress(img.encodePng(page)))!;
    expect((result.width, result.height), (80, 120));
    expect(result.getPixel(0, 0).r, greaterThan(250));
    expect(result.getPixel(40, 35).r, lessThan(5));
  });
  test('EXIF phone orientation is baked into the JPEG exactly once', () {
    final page = img.Image(width: 80, height: 120);
    img.fill(page, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(
      page,
      x1: 0,
      y1: 0,
      x2: 39,
      y2: 59,
      color: img.ColorRgb8(0, 0, 0),
    );
    page.exif.imageIfd.orientation = 6;
    final result =
        img.decodeJpg(ScanImageCompression.compress(img.encodeJpg(page)))!;
    expect((result.width, result.height), (120, 80));
    expect(result.exif.imageIfd.orientation, isNull);
    expect(result.getPixel(90, 20).r, lessThan(5));
    expect(result.getPixel(20, 20).r, greaterThan(250));
  });
  test('Already smaller JPEGs are preserved byte for byte', () {
    final page = img.Image(width: 200, height: 300);
    for (final p in page) {
      p.setRgb(p.x % 256, p.y % 256, (p.x + p.y) % 256);
    }
    final source = img.encodeJpg(page, quality: 45);
    expect(ScanImageCompression.compress(source), source);
  });
  test('Unreadable input fails instead of creating a blank page', () {
    expect(
      () => ScanImageCompression.compress(Uint8List.fromList([1, 2, 3])),
      throwsStateError,
    );
  });
}
