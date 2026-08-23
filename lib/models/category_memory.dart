import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

/// The category this merchant was last filed under, or null if it is new.
///
/// "Last" means most recently saved, by [Receipt.createdAt] — ids are random
/// strings and say nothing about order.
ReceiptCategory? rememberedCategoryFor(
  List<Receipt> receipts,
  String merchant,
) {
  final normalized = merchant.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  final matches =
      receipts
          .where(
            (receipt) => receipt.merchant.trim().toLowerCase() == normalized,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  if (matches.isEmpty) return null;
  return ReceiptCategory.fromName(matches.first.category);
}

/// Every other receipt from the same merchant, for offering to re-file them
/// all at once. [excludeId] is the receipt being edited, or null when adding
/// a new one that has no id yet.
List<Receipt> otherReceiptsForMerchant(
  List<Receipt> receipts,
  String merchant,
  String? excludeId,
) {
  final normalized = merchant.trim().toLowerCase();
  if (normalized.isEmpty) return const [];

  return receipts
      .where(
        (receipt) =>
            receipt.id != excludeId &&
            receipt.merchant.trim().toLowerCase() == normalized,
      )
      .toList();
}
