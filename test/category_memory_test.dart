import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/category_memory.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

Receipt _receipt({
  required String id,
  required String merchant,
  required String category,
  DateTime? createdAt,
}) {
  return Receipt(
    id: id,
    merchant: merchant,
    amountYen: 100,
    date: DateTime(2026, 8, 1),
    category: category,
    createdAt: createdAt ?? DateTime(2026, 8, 1),
  );
}

void main() {
  test('returns null when no receipt matches the merchant', () {
    final receipts = [
      _receipt(id: '1', merchant: 'セブン-イレブン', category: 'groceries'),
    ];

    expect(rememberedCategoryFor(receipts, 'ローソン'), isNull);
  });

  test('returns null for a blank merchant', () {
    final receipts = [
      _receipt(id: '1', merchant: 'セブン-イレブン', category: 'groceries'),
    ];

    expect(rememberedCategoryFor(receipts, '   '), isNull);
  });

  test('matches merchant names case-insensitively and ignoring whitespace', () {
    final receipts = [
      _receipt(id: '1', merchant: 'Starbucks', category: 'dining'),
    ];

    expect(
      rememberedCategoryFor(receipts, '  starbucks  '),
      ReceiptCategory.dining,
    );
  });

  test('uses the most recently saved receipt when a merchant has several', () {
    // Firestore ids are random, so they say nothing about recency. The ids
    // here sort the opposite way to createdAt on purpose: anything ordering
    // by id would pick 'dining' and be wrong.
    final receipts = [
      _receipt(
        id: 'zzz',
        merchant: 'Starbucks',
        category: 'dining',
        createdAt: DateTime(2026, 8, 1),
      ),
      _receipt(
        id: 'aaa',
        merchant: 'Starbucks',
        category: 'shopping',
        createdAt: DateTime(2026, 8, 20),
      ),
    ];

    expect(
      rememberedCategoryFor(receipts, 'Starbucks'),
      ReceiptCategory.shopping,
    );
  });

  group('otherReceiptsForMerchant', () {
    test('excludes the receipt being edited', () {
      final receipts = [
        _receipt(id: '1', merchant: 'Starbucks', category: 'dining'),
      ];

      expect(otherReceiptsForMerchant(receipts, 'Starbucks', '1'), isEmpty);
    });

    test('matches merchant case-insensitively and ignoring whitespace', () {
      final receipts = [
        _receipt(id: '1', merchant: 'Starbucks', category: 'dining'),
        _receipt(id: '2', merchant: '  starbucks  ', category: 'dining'),
        _receipt(id: '3', merchant: 'Not Starbucks', category: 'shopping'),
      ];

      final others = otherReceiptsForMerchant(receipts, 'Starbucks', '1');

      expect(others.map((r) => r.id), ['2']);
    });

    test('returns empty when no other receipt shares the merchant', () {
      final receipts = [
        _receipt(id: '1', merchant: 'Starbucks', category: 'dining'),
        _receipt(id: '2', merchant: 'Lawson', category: 'groceries'),
      ];

      expect(otherReceiptsForMerchant(receipts, 'Starbucks', '1'), isEmpty);
    });

    test('keeps every same-merchant receipt when adding a new one', () {
      // A brand-new receipt has no id yet, so nothing should be excluded.
      final receipts = [
        _receipt(id: '1', merchant: 'Starbucks', category: 'dining'),
        _receipt(id: '2', merchant: 'Starbucks', category: 'dining'),
      ];

      final others = otherReceiptsForMerchant(receipts, 'Starbucks', null);

      expect(others.map((r) => r.id), ['1', '2']);
    });
  });
}
