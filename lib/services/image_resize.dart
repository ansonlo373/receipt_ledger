import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Long edge, in pixels, that photos are shrunk to before leaving the device.
///
/// Gemini charges image input by 768px tiles, so cost scales with resolution,
/// not file size. 1536 is two tiles across — enough that receipt line items
/// stay legible, while a raw 4000px camera photo would cost several times as
/// much for detail the model cannot use.
const int defaultMaxDimension = 1536;

/// Quality high enough that JPEG artefacts don't blur small printed digits,
/// low enough to keep the upload quick on mobile data.
const int defaultJpegQuality = 85;

/// Shrinks [original] so its longest edge is at most [maxDimension], and
/// re-encodes it as JPEG. A photo already within the limit keeps its size —
/// enlarging invents no detail and only costs tokens.
///
/// Throws [ArgumentError] if the bytes aren't a decodable image.
Uint8List resizeJpegBytes(
  List<int> original, {
  int maxDimension = defaultMaxDimension,
  int quality = defaultJpegQuality,
}) {
  final decoded = img.decodeImage(Uint8List.fromList(original));
  if (decoded == null) {
    throw ArgumentError('Not a decodable image');
  }

  final longestEdge = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longestEdge <= maxDimension) {
    return img.encodeJpg(decoded, quality: quality);
  }

  // Constrain the longer edge and let the package derive the other, so the
  // aspect ratio is preserved — important for tall, narrow receipts.
  final resized = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: maxDimension)
      : img.copyResize(decoded, height: maxDimension);

  return img.encodeJpg(resized, quality: quality);
}

/// Reads the photo at [path] and returns it resized, ready to upload.
Future<Uint8List> readResizedJpeg(
  String path, {
  int maxDimension = defaultMaxDimension,
  int quality = defaultJpegQuality,
}) async {
  final bytes = await File(path).readAsBytes();
  return resizeJpegBytes(bytes, maxDimension: maxDimension, quality: quality);
}
