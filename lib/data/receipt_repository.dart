import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

/// What the app needs from storage, with no hint of what is behind it, so
/// screens and tests can be handed a fake instead of a real database.
abstract class ReceiptRepository {
  /// Live receipts, newest receipt date first. Excludes the trash.
  Stream<List<Receipt>> watchAll();

  /// Soft-deleted receipts, most recently deleted first.
  Stream<List<Receipt>> watchTrash();

  /// Returns the new receipt's id, so a caller can immediately attach
  /// something to it — the photo upload needs this.
  Future<String> add({
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
    String? photoPath,
  });

  Future<void> update({
    required String id,
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
    String? photoPath,
  });

  /// Records the uploaded photo's download URL. Separate from [update] so a
  /// background upload finishing does not have to rewrite the whole receipt
  /// and risk clobbering an edit the user made in the meantime.
  Future<void> setPhotoUrl({required String id, required String photoUrl});

  Future<void> softDelete(String id);

  Future<void> restore(String id);

  Future<void> purgeExpiredTrash({
    Duration retention = const Duration(days: 30),
  });
}
