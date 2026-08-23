import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:receipt_ledger/services/image_resize.dart';

/// A JPEG of the given size, standing in for a camera photo.
List<int> _jpegOfSize(int width, int height) {
  return img.encodeJpg(img.Image(width: width, height: height));
}

void main() {
  test('shrinks a large photo so its long edge hits the limit', () {
    final original = _jpegOfSize(4000, 3000);

    final resized = img.decodeJpg(resizeJpegBytes(original))!;

    expect(resized.width, 1536);
    expect(resized.height, 1152); // aspect ratio preserved
  });

  test('shrinks by height when the photo is taller than it is wide', () {
    // The common case here: receipts are long and narrow.
    final original = _jpegOfSize(1000, 4000);

    final resized = img.decodeJpg(resizeJpegBytes(original))!;

    expect(resized.height, 1536);
    expect(resized.width, 384);
  });

  test('leaves a photo already under the limit at its original size', () {
    // Upscaling would add no detail for the model to read, only tokens.
    final original = _jpegOfSize(800, 600);

    final resized = img.decodeJpg(resizeJpegBytes(original))!;

    expect(resized.width, 800);
    expect(resized.height, 600);
  });

  test('honours a caller-supplied dimension limit', () {
    final original = _jpegOfSize(4000, 2000);

    final resized = img.decodeJpg(
      resizeJpegBytes(original, maxDimension: 500),
    )!;

    expect(resized.width, 500);
    expect(resized.height, 250);
  });

  test('makes a big photo substantially smaller on the wire', () {
    final original = _jpegOfSize(4000, 3000);

    final resized = resizeJpegBytes(original);

    expect(resized.length, lessThan(original.length));
  });

  test('throws on bytes that are not a decodable image', () {
    expect(() => resizeJpegBytes([1, 2, 3, 4]), throwsA(isA<ArgumentError>()));
  });
}
