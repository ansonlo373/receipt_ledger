import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/models/receipt_filter.dart';

Receipt _receipt({
  required String merchant,
  required DateTime date,
  required String category,
}) {
  return Receipt(
    id: '1',
    merchant: merchant,
    amountYen: 100,
    date: date,
    category: category,
    createdAt: date,
    notes: null,
  );
}

void main() {
  test('an empty filter matches everything', () {
    const filter = ReceiptFilter();
    final receipt = _receipt(
      merchant: 'Anything',
      date: DateTime(2026, 1, 1),
      category: 'groceries',
    );

    expect(filter.matches(receipt), isTrue);
  });

  test(
    'a category filter only matches receipts in one of the selected categories',
    () {
      const filter = ReceiptFilter(
        categories: {ReceiptCategory.groceries, ReceiptCategory.dining},
      );
      final groceries = _receipt(
        merchant: 'A',
        date: DateTime(2026, 1, 1),
        category: 'groceries',
      );
      final transport = _receipt(
        merchant: 'B',
        date: DateTime(2026, 1, 1),
        category: 'transport',
      );

      expect(filter.matches(groceries), isTrue);
      expect(filter.matches(transport), isFalse);
    },
  );

  test('a date range filter matches on the boundary dates (inclusive) but not outside them', () {
    final filter = ReceiptFilter(
      dateRange: DateTimeRange(
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 19),
      ),
    );
    final before = _receipt(
      merchant: 'Before',
      date: DateTime(2026, 8, 9),
      category: 'groceries',
    );
    final startBoundary = _receipt(
      merchant: 'Start',
      date: DateTime(2026, 8, 10),
      category: 'groceries',
    );
    final endBoundary = _receipt(
      merchant: 'End',
      date: DateTime(2026, 8, 19),
      category: 'groceries',
    );
    final after = _receipt(
      merchant: 'After',
      date: DateTime(2026, 8, 20),
      category: 'groceries',
    );

    expect(filter.matches(before), isFalse);
    expect(filter.matches(startBoundary), isTrue);
    expect(filter.matches(endBoundary), isTrue);
    expect(filter.matches(after), isFalse);
  });
}
