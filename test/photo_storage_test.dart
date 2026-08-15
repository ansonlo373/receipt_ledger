import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/services/photo_storage.dart';

void main() {
  test('keeps the source file\'s extension', () {
    final name = buildPhotoFileName(
      timestamp: DateTime(2026, 8, 15, 10, 30),
      sourcePath: '/cache/image_picker/abc123.jpg',
    );

    expect(name.endsWith('.jpg'), isTrue);
  });

  test('lowercases the extension', () {
    final name = buildPhotoFileName(
      timestamp: DateTime(2026, 8, 15, 10, 30),
      sourcePath: '/cache/image_picker/abc123.PNG',
    );

    expect(name.endsWith('.png'), isTrue);
  });

  test('produces distinct names for distinct timestamps', () {
    final first = buildPhotoFileName(
      timestamp: DateTime(2026, 8, 15, 10, 30, 0, 0),
      sourcePath: '/x/a.jpg',
    );
    final second = buildPhotoFileName(
      timestamp: DateTime(2026, 8, 15, 10, 30, 0, 1),
      sourcePath: '/x/a.jpg',
    );

    expect(first, isNot(second));
  });
}
