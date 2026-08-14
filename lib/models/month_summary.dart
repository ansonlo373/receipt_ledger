import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

class CategoryTotal {
  const CategoryTotal({required this.category, required this.amountYen});

  final ReceiptCategory category;
  final int amountYen;
}

class MonthSummary {
  const MonthSummary({
    required this.totalYen,
    required this.previousMonthTotalYen,
    required this.topCategories,
    required this.recent,
  });

  final int totalYen;
  final int previousMonthTotalYen;
  final List<CategoryTotal> topCategories;
  final List<Receipt> recent;

  factory MonthSummary.of(List<Receipt> receipts, DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final nextMonthStart = DateTime(month.year, month.month + 1, 1);
    final previousMonthStart = DateTime(month.year, month.month - 1, 1);

    bool inRange(DateTime date, DateTime start, DateTime end) {
      return !date.isBefore(start) && date.isBefore(end);
    }

    int totalBetween(DateTime start, DateTime end) {
      return receipts
          .where((r) => inRange(r.date, start, end))
          .fold<int>(0, (sum, r) => sum + r.amountYen);
    }

    final inMonth = receipts.where(
      (r) => inRange(r.date, monthStart, nextMonthStart),
    );

    final totalsByCategory = <ReceiptCategory, int>{};
    for (final receipt in inMonth) {
      final category = ReceiptCategory.fromName(receipt.category);
      totalsByCategory[category] =
          (totalsByCategory[category] ?? 0) + receipt.amountYen;
    }

    final topCategories = totalsByCategory.entries
        .map((e) => CategoryTotal(category: e.key, amountYen: e.value))
        .toList()
      ..sort((a, b) => b.amountYen.compareTo(a.amountYen));

    final recent = [...receipts]
      ..sort((a, b) => b.date.compareTo(a.date));

    return MonthSummary(
      totalYen: totalBetween(monthStart, nextMonthStart),
      previousMonthTotalYen: totalBetween(previousMonthStart, monthStart),
      topCategories: topCategories.take(3).toList(),
      recent: recent.take(3).toList(),
    );
  }
}
