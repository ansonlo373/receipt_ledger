import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/category_memory.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

Receipt _receipt({
  required int id,
  required String merchant,
  required String category,
}) {
  return Receipt(
    id: id,
    merchant: merchant,
    amountYen: 100,
    date: DateTime(2026, 8, id),
    category: category,
    notes: null,
  );
}

void main() {
  test('returns null when no receipt matches the merchant', () {
    final receipts = [
      _receipt(id: 1, merchant: 'セブン-イレブン', category: 'groceries'),
    ];

    expect(rememberedCategoryFor(receipts, 'ローソン'), isNull);
  });

  test('returns null for a blank merchant', () {
    final receipts = [
      _receipt(id: 1, merchant: 'セブン-イレブン', category: 'groceries'),
    ];

    expect(rememberedCategoryFor(receipts, '   '), isNull);
  });

  test('matches merchant names case-insensitively and ignoring whitespace', () {
    final receipts = [
      _receipt(id: 1, merchant: 'Starbucks', category: 'dining'),
    ];

    expect(
      rememberedCategoryFor(receipts, '  starbucks  '),
      ReceiptCategory.dining,
    );
  });

  test('uses the most recently saved receipt when a merchant has several', () {
    final receipts = [
      _receipt(id: 1, merchant: 'Starbucks', category: 'dining'),
      _receipt(id: 2, merchant: 'Starbucks', category: 'shopping'),
    ];

    expect(
      rememberedCategoryFor(receipts, 'Starbucks'),
      ReceiptCategory.shopping,
    );
  });

  group('otherReceiptsForMerchant', () {
    test('excludes the receipt being edited', () {
      final receipts = [
        _receipt(id: 1, merchant: 'Starbucks', category: 'dining'),
      ];

      expect(
        otherReceiptsForMerchant(receipts, 'Starbucks', 1),
        isEmpty,
      );
    });

    test('matches merchant case-insensitively and ignoring whitespace', () {
      final receipts = [
        _receipt(id: 1, merchant: 'Starbucks', category: 'dining'),
        _receipt(id: 2, merchant: '  starbucks  ', category: 'dining'),
        _receipt(id: 3, merchant: 'Not Starbucks', category: 'shopping'),
      ];

      final others = otherReceiptsForMerchant(receipts, 'Starbucks', 1);

      expect(others.map((r) => r.id), [2]);
    });

    test('returns empty when no other receipt shares the merchant', () {
      final receipts = [
        _receipt(id: 1, merchant: 'Starbucks', category: 'dining'),
        _receipt(id: 2, merchant: 'Lawson', category: 'groceries'),
      ];

      expect(otherReceiptsForMerchant(receipts, 'Starbucks', 1), isEmpty);
    });
  });
}
