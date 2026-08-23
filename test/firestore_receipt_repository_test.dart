import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/data/firestore_receipt_repository.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReceiptRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreReceiptRepository(firestore: firestore, uid: 'user1');
  });

  test('add stores a receipt that watchAll emits', () async {
    await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      notes: null,
    );

    final receipts = await repository.watchAll().first;

    expect(receipts, hasLength(1));
    expect(receipts.single.merchant, 'Trader Joe\'s');
    expect(receipts.single.amountYen, 4599);
    expect(receipts.single.category, 'groceries');
  });

  test(
    'add returns the new id so the caller can attach a photo to it',
    () async {
      final id = await repository.add(
        merchant: 'Trader Joe\'s',
        amountYen: 4599,
        date: DateTime(2026, 8, 10),
        category: ReceiptCategory.groceries,
      );

      final stored = (await repository.watchAll().first).single;
      expect(id, stored.id);
    },
  );

  test('update changes an existing receipt that watchAll reflects', () async {
    final id = await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
    );

    await repository.update(
      id: id,
      merchant: 'Whole Foods',
      amountYen: 5200,
      date: DateTime(2026, 8, 11),
      category: ReceiptCategory.dining,
      notes: 'birthday dinner',
    );

    final receipts = await repository.watchAll().first;

    expect(receipts, hasLength(1));
    expect(receipts.single.merchant, 'Whole Foods');
    expect(receipts.single.amountYen, 5200);
    expect(receipts.single.category, 'dining');
    expect(receipts.single.notes, 'birthday dinner');
  });

  test(
    'add and update both store a photoPath that watchAll reflects',
    () async {
      final id = await repository.add(
        merchant: 'Trader Joe\'s',
        amountYen: 4599,
        date: DateTime(2026, 8, 10),
        category: ReceiptCategory.groceries,
        photoPath: '/receipts/photo1.jpg',
      );
      expect(
        (await repository.watchAll().first).single.photoPath,
        '/receipts/photo1.jpg',
      );

      await repository.update(
        id: id,
        merchant: 'Trader Joe\'s',
        amountYen: 4599,
        date: DateTime(2026, 8, 10),
        category: ReceiptCategory.groceries,
        photoPath: null,
      );

      expect((await repository.watchAll().first).single.photoPath, isNull);
    },
  );

  test('setPhotoUrl records the upload without disturbing the rest', () async {
    final id = await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      photoPath: '/receipts/photo1.jpg',
    );

    await repository.setPhotoUrl(id: id, photoUrl: 'https://example/p1.jpg');

    final stored = (await repository.watchAll().first).single;
    expect(stored.photoUrl, 'https://example/p1.jpg');
    expect(stored.merchant, 'Trader Joe\'s');
    expect(stored.photoPath, '/receipts/photo1.jpg');
  });

  test('editing a receipt leaves an already-uploaded photoUrl alone', () async {
    // The upload finishes in the background; an unrelated edit afterwards
    // must not wipe out the URL and strand the photo.
    final id = await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      photoPath: '/receipts/photo1.jpg',
    );
    await repository.setPhotoUrl(id: id, photoUrl: 'https://example/p1.jpg');

    await repository.update(
      id: id,
      merchant: 'Whole Foods',
      amountYen: 5200,
      date: DateTime(2026, 8, 11),
      category: ReceiptCategory.dining,
      photoPath: '/receipts/photo1.jpg',
    );

    final stored = (await repository.watchAll().first).single;
    expect(stored.photoUrl, 'https://example/p1.jpg');
    expect(stored.merchant, 'Whole Foods');
  });

  test(
    'softDelete removes a receipt from watchAll but keeps it in watchTrash',
    () async {
      final id = await repository.add(
        merchant: 'Trader Joe\'s',
        amountYen: 4599,
        date: DateTime(2026, 8, 10),
        category: ReceiptCategory.groceries,
      );

      await repository.softDelete(id);

      expect(await repository.watchAll().first, isEmpty);

      final trash = await repository.watchTrash().first;
      expect(trash, hasLength(1));
      expect(trash.single.id, id);
      expect(trash.single.deletedAt, isNotNull);
    },
  );

  test('restore moves a receipt back from watchTrash into watchAll', () async {
    final id = await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
    );
    await repository.softDelete(id);

    await repository.restore(id);

    final active = await repository.watchAll().first;
    expect(active, hasLength(1));
    expect(active.single.deletedAt, isNull);
    expect(await repository.watchTrash().first, isEmpty);
  });

  test('watchAll returns receipts newest receipt-date first', () async {
    await repository.add(
      merchant: 'Older',
      amountYen: 100,
      date: DateTime(2026, 8, 1),
      category: ReceiptCategory.groceries,
    );
    await repository.add(
      merchant: 'Newer',
      amountYen: 200,
      date: DateTime(2026, 8, 20),
      category: ReceiptCategory.groceries,
    );

    final receipts = await repository.watchAll().first;

    expect(receipts.map((r) => r.merchant), ['Newer', 'Older']);
  });

  test(
    'purgeExpiredTrash removes only trash older than the retention window',
    () async {
      final old = await repository.add(
        merchant: 'Old (should purge)',
        amountYen: 100,
        date: DateTime(2026, 1, 1),
        category: ReceiptCategory.groceries,
      );
      final recent = await repository.add(
        merchant: 'Recent (should stay)',
        amountYen: 200,
        date: DateTime(2026, 1, 2),
        category: ReceiptCategory.groceries,
      );

      await repository.softDelete(old);
      await repository.softDelete(recent);
      // softDelete always stamps "now", so backdate the old one directly to
      // put it outside the retention window.
      await firestore
          .collection('users')
          .doc('user1')
          .collection('receipts')
          .doc(old)
          .update({
            'deletedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 31)),
            ),
          });

      await repository.purgeExpiredTrash(retention: const Duration(days: 30));

      final trash = await repository.watchTrash().first;
      expect(trash, hasLength(1));
      expect(trash.single.merchant, 'Recent (should stay)');
    },
  );

  test('one account cannot see another account receipts', () async {
    await repository.add(
      merchant: 'User 1 receipt',
      amountYen: 100,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
    );

    final otherUser = FirestoreReceiptRepository(
      firestore: firestore,
      uid: 'user2',
    );

    expect(await otherUser.watchAll().first, isEmpty);
  });
}
