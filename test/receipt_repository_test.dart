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

  test('delete removes a receipt that watchAll reflects', () async {
    await repository.add(
      merchant: 'Trader Joe\'s',
      amountYen: 4599,
      date: DateTime(2026, 8, 10),
      category: ReceiptCategory.groceries,
      notes: null,
    );
    final stored = (await repository.watchAll().first).single;

    await repository.delete(stored.id);

    final receipts = await repository.watchAll().first;
    expect(receipts, isEmpty);
  });
}
