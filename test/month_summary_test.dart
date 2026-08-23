import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/month_summary.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

Receipt _receipt({
  required int id,
  required String merchant,
  required int amountYen,
  required DateTime date,
  required String category,
}) {
  return Receipt(
    id: id.toString(),
    merchant: merchant,
    amountYen: amountYen,
    date: date,
    category: category,
    createdAt: date,
    notes: null,
  );
}

void main() {
  test('totals only the receipts within the target month', () {
    final receipts = [
      _receipt(
        id: 1,
        merchant: 'In August',
        amountYen: 1000,
        date: DateTime(2026, 8, 5),
        category: 'groceries',
      ),
      _receipt(
        id: 2,
        merchant: 'Also August',
        amountYen: 500,
        date: DateTime(2026, 8, 31),
        category: 'groceries',
      ),
      _receipt(
        id: 3,
        merchant: 'In July',
        amountYen: 9999,
        date: DateTime(2026, 7, 31),
        category: 'groceries',
      ),
      _receipt(
        id: 4,
        merchant: 'In September',
        amountYen: 9999,
        date: DateTime(2026, 9, 1),
        category: 'groceries',
      ),
    ];

    final summary = MonthSummary.of(receipts, DateTime(2026, 8, 15));

    expect(summary.totalYen, 1500);
  });

  test('previousMonthTotalYen totals only the prior calendar month', () {
    final receipts = [
      _receipt(
        id: 1,
        merchant: 'In August',
        amountYen: 1000,
        date: DateTime(2026, 8, 5),
        category: 'groceries',
      ),
      _receipt(
        id: 2,
        merchant: 'In July',
        amountYen: 300,
        date: DateTime(2026, 7, 1),
        category: 'groceries',
      ),
      _receipt(
        id: 3,
        merchant: 'Also July',
        amountYen: 400,
        date: DateTime(2026, 7, 31),
        category: 'groceries',
      ),
      _receipt(
        id: 4,
        merchant: 'In June',
        amountYen: 9999,
        date: DateTime(2026, 6, 30),
        category: 'groceries',
      ),
    ];

    final summary = MonthSummary.of(receipts, DateTime(2026, 8, 15));

    expect(summary.previousMonthTotalYen, 700);
  });

  test('handles a January target month by looking back to December', () {
    final receipts = [
      _receipt(
        id: 1,
        merchant: 'Last December',
        amountYen: 250,
        date: DateTime(2025, 12, 20),
        category: 'groceries',
      ),
    ];

    final summary = MonthSummary.of(receipts, DateTime(2026, 1, 10));

    expect(summary.previousMonthTotalYen, 250);
  });

  test('allCategories ranks by total descending, ignoring other months', () {
    final receipts = [
      _receipt(
        id: 1,
        merchant: 'A',
        amountYen: 100,
        date: DateTime(2026, 8, 1),
        category: 'transport',
      ),
      _receipt(
        id: 2,
        merchant: 'B',
        amountYen: 500,
        date: DateTime(2026, 8, 2),
        category: 'groceries',
      ),
      _receipt(
        id: 3,
        merchant: 'C',
        amountYen: 300,
        date: DateTime(2026, 8, 3),
        category: 'dining',
      ),
      _receipt(
        id: 4,
        merchant: 'D',
        amountYen: 200,
        date: DateTime(2026, 8, 4),
        category: 'shopping',
      ),
      _receipt(
        id: 5,
        merchant: 'E (last month, excluded)',
        amountYen: 9999,
        date: DateTime(2026, 7, 4),
        category: 'utilities',
      ),
    ];

    final summary = MonthSummary.of(receipts, DateTime(2026, 8, 15));

    expect(summary.allCategories, hasLength(4));
    expect(summary.allCategories[0].category, ReceiptCategory.groceries);
    expect(summary.allCategories[0].amountYen, 500);
    expect(summary.allCategories[1].category, ReceiptCategory.dining);
    expect(summary.allCategories[1].amountYen, 300);
    expect(summary.allCategories[2].category, ReceiptCategory.shopping);
    expect(summary.allCategories[2].amountYen, 200);
    expect(summary.allCategories[3].category, ReceiptCategory.transport);
    expect(summary.allCategories[3].amountYen, 100);
  });
}
