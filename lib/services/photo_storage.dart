import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String buildPhotoFileName({
  required DateTime timestamp,
  required String sourcePath,
}) {
  final extension = p.extension(sourcePath).toLowerCase();
  return '${timestamp.microsecondsSinceEpoch}$extension';
}

/// Copies a picked image into the app's own documents directory (under
/// receipt_photos/) so it survives after the image_picker cache is cleared,
/// and returns the path it was saved to.
Future<String> savePhotoLocally(String sourcePath) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final photosDir = Directory(p.join(docsDir.path, 'receipt_photos'));
  await photosDir.create(recursive: true);

  final fileName = buildPhotoFileName(
    timestamp: DateTime.now(),
    sourcePath: sourcePath,
  );
  final destination = p.join(photosDir.path, fileName);
  await File(sourcePath).copy(destination);
  return destination;
}
