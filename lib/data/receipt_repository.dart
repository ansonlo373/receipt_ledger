import 'package:drift/drift.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

abstract class ReceiptRepository {
  Stream<List<Receipt>> watchAll();

  Future<void> add({
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
  });

  Future<void> update({
    required int id,
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
  });

  Future<void> delete(int id);
}

class DriftReceiptRepository implements ReceiptRepository {
  DriftReceiptRepository(this._database);

  final ReceiptsDatabase _database;

  @override
  Stream<List<Receipt>> watchAll() {
    return (_database.select(
      _database.receipts,
    )..orderBy([(r) => OrderingTerm.desc(r.date)])).watch();
  }

  @override
  Future<void> add({
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
  }) {
    return _database
        .into(_database.receipts)
        .insert(
          ReceiptsCompanion.insert(
            merchant: merchant,
            amountYen: amountYen,
            date: date,
            category: category.name,
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<void> update({
    required int id,
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
  }) {
    return (_database.update(_database.receipts)
          ..where((r) => r.id.equals(id)))
        .write(
          ReceiptsCompanion(
            merchant: Value(merchant),
            amountYen: Value(amountYen),
            date: Value(date),
            category: Value(category.name),
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<void> delete(int id) {
    return (_database.delete(
      _database.receipts,
    )..where((r) => r.id.equals(id))).go();
  }
}
