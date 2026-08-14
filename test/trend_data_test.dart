import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/models/trend_data.dart';

Receipt _receipt({
  required int id,
  required int amountYen,
  required DateTime date,
  required String category,
}) {
  return Receipt(
    id: id,
    merchant: 'M',
    amountYen: amountYen,
    date: date,
    category: category,
    notes: null,
  );
}

void main() {
  test('buildTrendBuckets sums by calendar month, oldest bucket first', () {
    final receipts = [
      _receipt(id: 1, amountYen: 100, date: DateTime(2026, 6, 5), category: 'groceries'),
      _receipt(id: 2, amountYen: 50, date: DateTime(2026, 6, 20), category: 'dining'),
      _receipt(id: 3, amountYen: 200, date: DateTime(2026, 7, 1), category: 'groceries'),
      _receipt(id: 4, amountYen: 300, date: DateTime(2026, 8, 15), category: 'groceries'),
    ];

    final buckets = buildTrendBuckets(
      receipts: receipts,
      granularity: TrendGranularity.month,
      referenceDate: DateTime(2026, 8, 15),
      bucketCount: 3,
    );

    expect(buckets, hasLength(3));
    expect(buckets[0].start, DateTime(2026, 6, 1));
    expect(buckets[0].amountYen, 150);
    expect(buckets[1].start, DateTime(2026, 7, 1));
    expect(buckets[1].amountYen, 200);
    expect(buckets[2].start, DateTime(2026, 8, 1));
    expect(buckets[2].amountYen, 300);
  });

  test('buildTrendBuckets only sums the given category when one is passed', () {
    final receipts = [
      _receipt(id: 1, amountYen: 100, date: DateTime(2026, 8, 5), category: 'groceries'),
      _receipt(id: 2, amountYen: 50, date: DateTime(2026, 8, 6), category: 'dining'),
    ];

    final buckets = buildTrendBuckets(
      receipts: receipts,
      granularity: TrendGranularity.month,
      referenceDate: DateTime(2026, 8, 15),
      category: ReceiptCategory.groceries,
      bucketCount: 1,
    );

    expect(buckets.single.amountYen, 100);
  });

  test('buildTrendBuckets with day granularity buckets by calendar day', () {
    final receipts = [
      _receipt(id: 1, amountYen: 100, date: DateTime(2026, 8, 13, 23, 59), category: 'groceries'),
      _receipt(id: 2, amountYen: 50, date: DateTime(2026, 8, 14, 0, 1), category: 'groceries'),
    ];

    final buckets = buildTrendBuckets(
      receipts: receipts,
      granularity: TrendGranularity.day,
      referenceDate: DateTime(2026, 8, 14),
      bucketCount: 2,
    );

    expect(buckets, hasLength(2));
    expect(buckets[0].start, DateTime(2026, 8, 13));
    expect(buckets[0].amountYen, 100);
    expect(buckets[1].start, DateTime(2026, 8, 14));
    expect(buckets[1].amountYen, 50);
  });

  test('buildTrendBuckets with year granularity buckets by calendar year', () {
    final receipts = [
      _receipt(id: 1, amountYen: 100, date: DateTime(2025, 12, 31), category: 'groceries'),
      _receipt(id: 2, amountYen: 50, date: DateTime(2026, 1, 1), category: 'groceries'),
    ];

    final buckets = buildTrendBuckets(
      receipts: receipts,
      granularity: TrendGranularity.year,
      referenceDate: DateTime(2026, 8, 14),
      bucketCount: 2,
    );

    expect(buckets, hasLength(2));
    expect(buckets[0].start, DateTime(2025, 1, 1));
    expect(buckets[0].amountYen, 100);
    expect(buckets[1].start, DateTime(2026, 1, 1));
    expect(buckets[1].amountYen, 50);
  });
}
