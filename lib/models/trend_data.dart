import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

enum TrendGranularity { day, month, year }

class TrendBucket {
  const TrendBucket({
    required this.start,
    required this.end,
    required this.amountYen,
  });

  final DateTime start;
  final DateTime end;
  final int amountYen;
}

List<TrendBucket> buildTrendBuckets({
  required List<Receipt> receipts,
  required TrendGranularity granularity,
  required DateTime referenceDate,
  ReceiptCategory? category,
  int bucketCount = 6,
}) {
  final periodStarts = <DateTime>[];
  for (var i = bucketCount - 1; i >= 0; i--) {
    switch (granularity) {
      case TrendGranularity.month:
        periodStarts.add(
          DateTime(referenceDate.year, referenceDate.month - i, 1),
        );
      case TrendGranularity.year:
        periodStarts.add(DateTime(referenceDate.year - i, 1, 1));
      case TrendGranularity.day:
        final day = DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
        );
        periodStarts.add(day.subtract(Duration(days: i)));
    }
  }

  DateTime endOf(DateTime start) {
    switch (granularity) {
      case TrendGranularity.month:
        return DateTime(start.year, start.month + 1, 1);
      case TrendGranularity.year:
        return DateTime(start.year + 1, 1, 1);
      case TrendGranularity.day:
        return start.add(const Duration(days: 1));
    }
  }

  final filtered = category == null
      ? receipts
      : receipts.where((r) => ReceiptCategory.fromName(r.category) == category);

  return [
    for (final start in periodStarts)
      TrendBucket(
        start: start,
        end: endOf(start),
        amountYen: filtered
            .where(
              (r) => !r.date.isBefore(start) && r.date.isBefore(endOf(start)),
            )
            .fold<int>(0, (sum, r) => sum + r.amountYen),
      ),
  ];
}
