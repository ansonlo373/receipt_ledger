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

  void _notify() => _changes.add(List.unmodifiable(_receipts));

  Stream<List<Receipt>> _watchWhere(bool Function(Receipt) test) {
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_receipts.where(test)));
      final subscription = _changes.stream
          .map((receipts) => receipts.where(test).toList())
          .listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<Receipt>> watchAll() =>
      _watchWhere((r) => r.deletedAt == null);

  @override
  Stream<List<Receipt>> watchTrash() =>
      _watchWhere((r) => r.deletedAt != null);

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
    _notify();
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
      deletedAt: _receipts[index].deletedAt,
    );
    _notify();
  }

  @override
  Future<void> softDelete(int id) async {
    final index = _receipts.indexWhere((r) => r.id == id);
    final r = _receipts[index];
    _receipts[index] = Receipt(
      id: r.id,
      merchant: r.merchant,
      amountYen: r.amountYen,
      date: r.date,
      category: r.category,
      notes: r.notes,
      deletedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> restore(int id) async {
    final index = _receipts.indexWhere((r) => r.id == id);
    final r = _receipts[index];
    _receipts[index] = Receipt(
      id: r.id,
      merchant: r.merchant,
      amountYen: r.amountYen,
      date: r.date,
      category: r.category,
      notes: r.notes,
    );
    _notify();
  }

  @override
  Future<void> purgeExpiredTrash({
    Duration retention = const Duration(days: 30),
  }) async {
    final cutoff = DateTime.now().subtract(retention);
    _receipts.removeWhere(
      (r) => r.deletedAt != null && r.deletedAt!.isBefore(cutoff),
    );
    _notify();
  }
}
