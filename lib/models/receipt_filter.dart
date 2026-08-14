import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

class ReceiptFilter {
  const ReceiptFilter({this.categories = const {}, this.dateRange});

  final Set<ReceiptCategory> categories;
  final DateTimeRange? dateRange;

  bool get isEmpty => categories.isEmpty && dateRange == null;

  ReceiptFilter copyWith({
    Set<ReceiptCategory>? categories,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return ReceiptFilter(
      categories: categories ?? this.categories,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }

  bool matches(Receipt receipt) {
    if (categories.isNotEmpty &&
        !categories.contains(ReceiptCategory.fromName(receipt.category))) {
      return false;
    }
    final range = dateRange;
    if (range != null) {
      final date = DateUtils.dateOnly(receipt.date);
      if (date.isBefore(range.start) || date.isAfter(range.end)) {
        return false;
      }
    }
    return true;
  }
}
