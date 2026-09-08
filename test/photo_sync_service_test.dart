import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/services/photo_sync_service.dart';

import 'fake_receipt_repository.dart';

Receipt _receipt({required String id, String? photoPath, String? photoUrl}) {
  return Receipt(
    id: id,
    merchant: 'M',
    amountYen: 100,
    date: DateTime(2026, 8, 1),
    category: 'groceries',
    createdAt: DateTime(2026, 8, 1),
    photoPath: photoPath,
    photoUrl: photoUrl,
  );
}

void main() {
  late FakeReceiptRepository repository;
  late List<String> uploadedPaths;

  /// Stands in for Firebase Storage: records what it was asked to upload and
  /// hands back a URL derived from the storage path.
  Future<String> succeedingUpload(String storagePath, Uint8List bytes) async {
    uploadedPaths.add(storagePath);
    return 'https://example/$storagePath';
  }

  setUp(() {
    repository = FakeReceiptRepository();
    uploadedPaths = [];
  });

  test('uploads a receipt whose photo has not reached the cloud yet', () async {
    final service = PhotoSyncService(
      repository: repository,
      uid: 'user1',
      uploadBytes: succeedingUpload,
      readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
    );

    await service.syncPendingPhotos([
      _receipt(id: 'r1', photoPath: '/local/a.jpg'),
    ]);

    expect(uploadedPaths, ['users/user1/receipt_photos/r1.jpg']);
  });

  test('skips a receipt whose photo is already uploaded', () async {
    final service = PhotoSyncService(
      repository: repository,
      uid: 'user1',
      uploadBytes: succeedingUpload,
      readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
    );

    await service.syncPendingPhotos([
      _receipt(
        id: 'r1',
        photoPath: '/local/a.jpg',
        photoUrl: 'https://example/already.jpg',
      ),
    ]);

    expect(uploadedPaths, isEmpty);
  });

  test('skips a receipt with no photo at all', () async {
    final service = PhotoSyncService(
      repository: repository,
      uid: 'user1',
      uploadBytes: succeedingUpload,
      readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
    );

    await service.syncPendingPhotos([_receipt(id: 'r1')]);

    expect(uploadedPaths, isEmpty);
  });

  test(
    'records the download URL against the receipt after uploading',
    () async {
      final id = await repository.add(
        merchant: 'M',
        amountYen: 100,
        date: DateTime(2026, 8, 1),
        category: ReceiptCategory.groceries,
        photoPath: '/local/a.jpg',
      );
      final service = PhotoSyncService(
        repository: repository,
        uid: 'user1',
        uploadBytes: succeedingUpload,
        readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
      );

      await service.syncPendingPhotos(await repository.watchAll().first);

      final stored = (await repository.watchAll().first).single;
      expect(
        stored.photoUrl,
        'https://example/users/user1/receipt_photos/$id.jpg',
      );
    },
  );

  test('one failed upload does not stop the others', () async {
    final service = PhotoSyncService(
      repository: repository,
      uid: 'user1',
      uploadBytes: (storagePath, bytes) async {
        // Matched on the filename, not a bare 'r1' — the uid 'user1'
        // contains that substring too.
        if (storagePath.endsWith('/r1.jpg')) throw Exception('network died');
        uploadedPaths.add(storagePath);
        return 'https://example/$storagePath';
      },
      readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
    );

    await service.syncPendingPhotos([
      _receipt(id: 'r1', photoPath: '/local/a.jpg'),
      _receipt(id: 'r2', photoPath: '/local/b.jpg'),
    ]);

    // r1 blew up, but r2 still went through — a sync sweep must not be
    // derailed by one bad file.
    expect(uploadedPaths, ['users/user1/receipt_photos/r2.jpg']);
  });

  test(
    'deleting a photo removes both the cloud copy and the local file',
    () async {
      final deletedStoragePaths = <String>[];
      final deletedLocalPaths = <String>[];
      final service = PhotoSyncService(
        repository: repository,
        uid: 'user1',
        uploadBytes: succeedingUpload,
        readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
        deleteRemote: (storagePath) async =>
            deletedStoragePaths.add(storagePath),
        deleteLocal: (path) async => deletedLocalPaths.add(path),
      );

      await service.deletePhoto(receiptId: 'r1', localPath: '/local/a.jpg');

      expect(deletedStoragePaths, ['users/user1/receipt_photos/r1.jpg']);
      expect(deletedLocalPaths, ['/local/a.jpg']);
    },
  );

  test(
    'deleting a photo clears the URL so it cannot reappear broken',
    () async {
      final id = await repository.add(
        merchant: 'M',
        amountYen: 100,
        date: DateTime(2026, 8, 1),
        category: ReceiptCategory.groceries,
        photoPath: '/local/a.jpg',
      );
      await repository.setPhotoUrl(id: id, photoUrl: 'https://example/a.jpg');
      final service = PhotoSyncService(
        repository: repository,
        uid: 'user1',
        uploadBytes: succeedingUpload,
        readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
        deleteRemote: (storagePath) async {},
        deleteLocal: (path) async {},
      );

      await service.deletePhoto(receiptId: id, localPath: '/local/a.jpg');

      // Leaving the URL set would point the app at a file that no longer
      // exists, showing a broken image instead of no image.
      expect((await repository.watchAll().first).single.photoUrl, isNull);
    },
  );

  test(
    'still deletes the cloud copy when the local file is already gone',
    () async {
      final deletedStoragePaths = <String>[];
      final service = PhotoSyncService(
        repository: repository,
        uid: 'user1',
        uploadBytes: succeedingUpload,
        readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
        deleteRemote: (storagePath) async =>
            deletedStoragePaths.add(storagePath),
        deleteLocal: (path) async => throw Exception('no such file'),
      );

      await service.deletePhoto(receiptId: 'r1', localPath: '/local/gone.jpg');

      expect(deletedStoragePaths, ['users/user1/receipt_photos/r1.jpg']);
    },
  );

  test(
    'deletes the local file even when the cloud copy cannot be removed',
    () async {
      // Offline, or the photo was never uploaded — the local file should still
      // go, rather than being stranded because the remote call failed.
      final deletedLocalPaths = <String>[];
      final service = PhotoSyncService(
        repository: repository,
        uid: 'user1',
        uploadBytes: succeedingUpload,
        readBytes: (path) async => Uint8List.fromList([1, 2, 3]),
        deleteRemote: (storagePath) async => throw Exception('offline'),
        deleteLocal: (path) async => deletedLocalPaths.add(path),
      );

      await service.deletePhoto(receiptId: 'r1', localPath: '/local/a.jpg');

      expect(deletedLocalPaths, ['/local/a.jpg']);
    },
  );

  test('a missing local file is skipped rather than throwing', () async {
    // The photo can be gone: cleared cache, restored backup, another device.
    final service = PhotoSyncService(
      repository: repository,
      uid: 'user1',
      uploadBytes: succeedingUpload,
      readBytes: (path) async => throw Exception('no such file'),
    );

    await service.syncPendingPhotos([
      _receipt(id: 'r1', photoPath: '/local/gone.jpg'),
    ]);

    expect(uploadedPaths, isEmpty);
  });
}
