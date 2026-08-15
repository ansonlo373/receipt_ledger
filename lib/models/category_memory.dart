import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

ReceiptCategory? rememberedCategoryFor(
  List<Receipt> receipts,
  String merchant,
) {
  final normalized = merchant.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  final matches = receipts
      .where((receipt) => receipt.merchant.trim().toLowerCase() == normalized)
      .toList()
    ..sort((a, b) => b.id.compareTo(a.id));

  if (matches.isEmpty) return null;
  return ReceiptCategory.fromName(matches.first.category);
}

List<Receipt> otherReceiptsForMerchant(
  List<Receipt> receipts,
  String merchant,
  int excludeId,
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
