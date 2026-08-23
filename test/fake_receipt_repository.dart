import 'dart:async';

import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

/// In-memory stand-in for [ReceiptRepository] used in widget tests, so tests
/// don't need Firebase running.
class FakeReceiptRepository implements ReceiptRepository {
  FakeReceiptRepository([List<Receipt> initial = const []])
    : _receipts = List.of(initial);

  final List<Receipt> _receipts;
  final _changes = StreamController<List<Receipt>>.broadcast();
  int _nextId = 1;

  /// Advances per add so receipts saved in sequence sort by creation the way
  /// they would in the real repository, without depending on wall-clock time.
  DateTime _nextCreatedAt = DateTime(2026, 1, 1);

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
  Stream<List<Receipt>> watchAll() => _watchWhere((r) => r.deletedAt == null);

  @override
  Stream<List<Receipt>> watchTrash() => _watchWhere((r) => r.deletedAt != null);

  @override
  Future<String> add({
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
    String? photoPath,
  }) async {
    final id = (_nextId++).toString();
    _nextCreatedAt = _nextCreatedAt.add(const Duration(minutes: 1));
    _receipts.add(
      Receipt(
        id: id,
        merchant: merchant,
        amountYen: amountYen,
        date: date,
        category: category.name,
        createdAt: _nextCreatedAt,
        notes: notes,
        photoPath: photoPath,
      ),
    );
    _notify();
    return id;
  }

  @override
  Future<void> update({
    required String id,
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
    String? photoPath,
  }) async {
    final index = _receipts.indexWhere((r) => r.id == id);
    final existing = _receipts[index];
    _receipts[index] = Receipt(
      id: id,
      merchant: merchant,
      amountYen: amountYen,
      date: date,
      category: category.name,
      createdAt: existing.createdAt,
      notes: notes,
      photoPath: photoPath,
      photoUrl: existing.photoUrl,
      deletedAt: existing.deletedAt,
    );
    _notify();
  }

  @override
  Future<void> setPhotoUrl({
    required String id,
    required String photoUrl,
  }) async {
    final index = _receipts.indexWhere((r) => r.id == id);
    final r = _receipts[index];
    _receipts[index] = Receipt(
      id: r.id,
      merchant: r.merchant,
      amountYen: r.amountYen,
      date: r.date,
      category: r.category,
      createdAt: r.createdAt,
      notes: r.notes,
      photoPath: r.photoPath,
      photoUrl: photoUrl,
      deletedAt: r.deletedAt,
    );
    _notify();
  }

  @override
  Future<void> softDelete(String id) async {
    final index = _receipts.indexWhere((r) => r.id == id);
    final r = _receipts[index];
    _receipts[index] = Receipt(
      id: r.id,
      merchant: r.merchant,
      amountYen: r.amountYen,
      date: r.date,
      category: r.category,
      createdAt: r.createdAt,
      notes: r.notes,
      photoPath: r.photoPath,
      photoUrl: r.photoUrl,
      deletedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> restore(String id) async {
    final index = _receipts.indexWhere((r) => r.id == id);
    final r = _receipts[index];
    _receipts[index] = Receipt(
      id: r.id,
      merchant: r.merchant,
      amountYen: r.amountYen,
      date: r.date,
      category: r.category,
      createdAt: r.createdAt,
      notes: r.notes,
      photoPath: r.photoPath,
      photoUrl: r.photoUrl,
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
