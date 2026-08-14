import 'dart:async';

import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

/// In-memory stand-in for [ReceiptRepository] used in widget tests, so tests
/// don't need a real SQLite connection (unavailable under `flutter test` on
/// Windows without a bundled native library).
class FakeReceiptRepository implements ReceiptRepository {
  FakeReceiptRepository([List<Receipt> initial = const []])
    : _receipts = List.of(initial);

  final List<Receipt> _receipts;
  final _changes = StreamController<List<Receipt>>.broadcast();
  int _nextId = 1;

  @override
  Stream<List<Receipt>> watchAll() {
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_receipts));
      final subscription = _changes.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> add({
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
  }) async {
    _receipts.add(
      Receipt(
        id: _nextId++,
        merchant: merchant,
        amountYen: amountYen,
        date: date,
        category: category.name,
        notes: notes,
      ),
    );
    _changes.add(List.unmodifiable(_receipts));
  }

  @override
  Future<void> update({
    required int id,
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
  }) async {
    final index = _receipts.indexWhere((r) => r.id == id);
    _receipts[index] = Receipt(
      id: id,
      merchant: merchant,
      amountYen: amountYen,
      date: date,
      category: category.name,
      notes: notes,
    );
    _changes.add(List.unmodifiable(_receipts));
  }

  @override
  Future<void> delete(int id) async {
    _receipts.removeWhere((r) => r.id == id);
    _changes.add(List.unmodifiable(_receipts));
  }
}
