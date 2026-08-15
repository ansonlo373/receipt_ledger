import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

void main() {
  late ReceiptsDatabase database;
  late ReceiptRepository repository;

  setUp(() {
    database = ReceiptsDatabase.forTesting(NativeDatabase.memory());
    repository = DriftReceiptRepository(database);
  });

  tearDown(() async {
    await database.close();
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

  test('update changes an existing receipt that watchAll reflects', () async {
    await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      notes: null,
    );
    final stored = (await repository.watchAll().first).single;

    await repository.update(
      id: stored.id,
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

  test('add and update both store a photoPath that watchAll reflects', () async {
    await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      notes: null,
      photoPath: '/receipts/photo1.jpg',
    );
    final stored = (await repository.watchAll().first).single;
    expect(stored.photoPath, '/receipts/photo1.jpg');

    await repository.update(
      id: stored.id,
      merchant: stored.merchant,
      amountYen: stored.amountYen,
      date: stored.date,
      category: ReceiptCategory.groceries,
      notes: stored.notes,
      photoPath: null,
    );

    final updated = (await repository.watchAll().first).single;
    expect(updated.photoPath, isNull);
  });

  test('softDelete removes a receipt from watchAll but keeps it in watchTrash', () async {
    await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      notes: null,
    );
    final stored = (await repository.watchAll().first).single;

    await repository.softDelete(stored.id);

    final active = await repository.watchAll().first;
    expect(active, isEmpty);

    final trash = await repository.watchTrash().first;
    expect(trash, hasLength(1));
    expect(trash.single.id, stored.id);
    expect(trash.single.deletedAt, isNotNull);
  });

  test('restore moves a receipt back from watchTrash into watchAll', () async {
    await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      notes: null,
    );
    final stored = (await repository.watchAll().first).single;
    await repository.softDelete(stored.id);

    await repository.restore(stored.id);

    final active = await repository.watchAll().first;
    expect(active, hasLength(1));
    expect(active.single.deletedAt, isNull);

    final trash = await repository.watchTrash().first;
    expect(trash, isEmpty);
  });

  test('purgeExpiredTrash permanently removes only trash older than the retention window', () async {
    await repository.add(
      merchant: 'Old (should purge)',
      amountYen: 100,
      date: DateTime(2026, 1, 1),
      category: ReceiptCategory.groceries,
      notes: null,
    );
    await repository.add(
      merchant: 'Recent (should stay)',
      amountYen: 200,
      date: DateTime(2026, 1, 2),
      category: ReceiptCategory.groceries,
      notes: null,
    );
    final stored = await repository.watchAll().first;
    final old = stored.firstWhere((r) => r.merchant == 'Old (should purge)');
    final recent = stored.firstWhere(
      (r) => r.merchant == 'Recent (should stay)',
    );

    await repository.softDelete(old.id);
    await repository.softDelete(recent.id);
    // Backdate the "old" one's deletion past the retention window directly,
    // since softDelete always stamps deletedAt with the current time.
    await database
        .into(database.receipts)
        .insertOnConflictUpdate(
          ReceiptsCompanion(
            id: Value(old.id),
            merchant: Value(old.merchant),
            amountYen: Value(old.amountYen),
            date: Value(old.date),
            category: Value(old.category),
            notes: Value(old.notes),
            deletedAt: Value(
              DateTime.now().subtract(const Duration(days: 31)),
            ),
          ),
        );

    await repository.purgeExpiredTrash(
      retention: const Duration(days: 30),
    );

    final trash = await repository.watchTrash().first;
    expect(trash, hasLength(1));
    expect(trash.single.merchant, 'Recent (should stay)');
  });
}
