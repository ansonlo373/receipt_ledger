import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shows a receipt's photo from wherever it can actually be found.
///
/// The local file wins when it exists: it is instant, works offline, and
/// costs no download. [photoUrl] is the fallback for every other device, and
/// for this one after a reinstall. When a receipt has a photo that is neither
/// on disk nor uploaded yet, it says so rather than showing a broken frame.
class ReceiptPhotoView extends StatelessWidget {
  const ReceiptPhotoView({
    super.key,
    this.photoPath,
    this.photoUrl,
    this.maxHeight = 400,
  });

  final String? photoPath;
  final String? photoUrl;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final localPath = photoPath;
    final hasLocalFile = localPath != null && File(localPath).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: _image(context, hasLocalFile ? localPath : null),
        ),
      ),
    );
  }

  Widget _image(BuildContext context, String? localPath) {
    // BoxFit.contain, never cover: a tall narrow receipt must be shown whole,
    // letterboxed if need be, rather than cropped top and bottom.
    if (localPath != null) {
      return Image.file(File(localPath), fit: BoxFit.contain);
    }

    final url = photoUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (context, _) => _message(context, 'Loading photo…'),
        errorWidget: (context, _, _) =>
            _message(context, 'Photo could not be loaded'),
      );
    }

    return _message(context, 'Photo will upload when you are back online');
  }

  Widget _message(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
