import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/services/image_resize.dart';

/// Uploads [bytes] to [storagePath] and returns a URL they can be read from.
typedef UploadBytes = Future<String> Function(
  String storagePath,
  Uint8List bytes,
);

/// Reads a local photo, resized and ready to upload.
typedef ReadBytes = Future<Uint8List> Function(String path);

/// Removes the copy stored at [storagePath] in the cloud.
typedef DeleteRemote = Future<void> Function(String storagePath);

/// Removes the copy at [path] on this device.
typedef DeleteLocal = Future<void> Function(String path);

/// Backs receipt photos up to cloud storage, so a photo outlives the phone
/// that took it.
///
/// Capture stays entirely local and instant; this runs afterwards, in the
/// background, and records a download URL on the receipt once the upload
/// lands. Both the upload and the file read are injected so the decision
/// logic can be tested without touching Firebase or the filesystem.
class PhotoSyncService {
  PhotoSyncService({
    required this.repository,
    required this.uid,
    UploadBytes? uploadBytes,
    ReadBytes? readBytes,
    DeleteRemote? deleteRemote,
    DeleteLocal? deleteLocal,
  }) : _uploadBytes = uploadBytes ?? _uploadToFirebaseStorage,
       _readBytes = readBytes ?? readResizedJpeg,
       _deleteRemote = deleteRemote ?? _deleteFromFirebaseStorage,
       _deleteLocal = deleteLocal ?? _deleteLocalFile;

  final ReceiptRepository repository;
  final String uid;
  final UploadBytes _uploadBytes;
  final ReadBytes _readBytes;
  final DeleteRemote _deleteRemote;
  final DeleteLocal _deleteLocal;

  /// Named after the receipt rather than the attempt, so a retry overwrites
  /// the previous try instead of leaving an orphan behind.
  String storagePathFor(String receiptId) =>
      'users/$uid/receipt_photos/$receiptId.jpg';

  /// Uploads one receipt's photo and records the resulting URL.
  ///
  /// Returns false if it didn't get there — the caller carries on regardless,
  /// since the next sweep will try again.
  Future<bool> uploadPhotoForReceipt({
    required String receiptId,
    required String localPath,
  }) async {
    try {
      final bytes = await _readBytes(localPath);
      final url = await _uploadBytes(storagePathFor(receiptId), bytes);
      await repository.setPhotoUrl(id: receiptId, photoUrl: url);
      return true;
    } catch (_) {
      // Offline, file deleted, upload rejected — all recoverable by trying
      // again later, and none worth interrupting the user over.
      return false;
    }
  }

  /// Removes a receipt's photo from the cloud and from this device.
  ///
  /// The two are attempted independently: a photo that was never uploaded, or
  /// a local file that is already gone, must not stop the other copy from
  /// being cleaned up. Neither failure is worth reporting — the receipt is
  /// what the user cares about, and a leftover file costs them nothing.
  Future<void> deletePhoto({
    required String receiptId,
    String? localPath,
  }) async {
    // Clear the URL first: a receipt still pointing at a deleted file shows
    // a broken image, which is worse than showing none.
    try {
      await repository.setPhotoUrl(id: receiptId, photoUrl: null);
    } catch (_) {
      // Receipt already gone (purged) — nothing to point anywhere.
    }

    try {
      await _deleteRemote(storagePathFor(receiptId));
    } catch (_) {
      // Never uploaded, offline, or already deleted.
    }

    if (localPath == null) return;
    try {
      await _deleteLocal(localPath);
    } catch (_) {
      // Already gone, or not this device's file.
    }
  }

  /// Uploads every photo that hasn't made it to the cloud yet.
  ///
  /// This is the retry mechanism: run at launch, it picks up anything that
  /// failed or was captured offline last time, so no separate background job
  /// or queue is needed.
  Future<void> syncPendingPhotos(List<Receipt> receipts) async {
    for (final receipt in receipts) {
      final localPath = receipt.photoPath;
      if (localPath == null || receipt.photoUrl != null) continue;
      await uploadPhotoForReceipt(receiptId: receipt.id, localPath: localPath);
    }
  }
}

Future<String> _uploadToFirebaseStorage(
  String storagePath,
  Uint8List bytes,
) async {
  final ref = FirebaseStorage.instance.ref(storagePath);
  await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}

Future<void> _deleteFromFirebaseStorage(String storagePath) {
  return FirebaseStorage.instance.ref(storagePath).delete();
}

Future<void> _deleteLocalFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
