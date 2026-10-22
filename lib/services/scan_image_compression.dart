import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Photo-only PDF pages: no OCR, thresholding or text reconstruction.
class ScanImageCompression {
  // Roughly 300 dpi for the long edge of an A4 page. Never upscale a photo.
  static const maxLongEdge = 3508;
  static const jpegQuality = 85;

  static Uint8List compress(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      throw StateError('Taranan görsel okunamadı.');
    }
    if (decoded == null) throw StateError('Taranan görsel okunamadı.');
    final orientation = decoded.exif.imageIfd.orientation;
    var picture =
        orientation != null && orientation != 1
            ? img.bakeOrientation(decoded)
            : decoded;
    final longEdge = math.max(picture.width, picture.height);
    final resized = longEdge > maxLongEdge;
    if (resized) {
      final scale = maxLongEdge / longEdge;
      picture = img.copyResize(
        picture,
        width: math.max(1, (picture.width * scale).round()),
        height: math.max(1, (picture.height * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }
    // JPEG has no alpha channel. Composite transparent pages on white paper.
    if (picture.hasAlpha) {
      final paper = img.Image(width: picture.width, height: picture.height);
      img.fill(paper, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(paper, picture);
      picture = paper;
    }
    picture.exif = img.ExifData();
    final jpeg = img.encodeJpg(
      picture,
      quality: jpegQuality,
      chroma: img.JpegChroma.yuv444,
    );
    // Already small JPEGs should not grow or suffer needless quality loss.
    if (!resized &&
        (orientation == null || orientation == 1) &&
        img.JpegDecoder().isValidFile(bytes) &&
        bytes.length <= jpeg.length) {
      return bytes;
    }
    return jpeg;
  }
}
