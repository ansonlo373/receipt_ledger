/// One saved receipt.
///
/// Plain Dart rather than a generated database row, so the storage layer can
/// change without every screen and every pure-logic helper changing with it.
class Receipt {
  const Receipt({
    required this.id,
    required this.merchant,
    required this.amountYen,
    required this.date,
    required this.category,
    required this.createdAt,
    this.notes,
    this.deletedAt,
    this.photoPath,
    this.photoUrl,
  });

  /// Firestore document id. A random string, so — unlike the old
  /// autoincrementing integer — it says nothing about when this receipt was
  /// saved; use [createdAt] for that.
  final String id;

  final String merchant;

  /// Whole yen. Japanese receipts have no decimal subunit.
  final int amountYen;

  /// The date printed on the receipt, not when it was entered.
  final DateTime date;

  /// A [ReceiptCategory] name. Stored as a string so an unknown value from a
  /// newer version of the app degrades to "other" instead of failing to load.
  final String category;

  /// When this receipt was saved. Exists because the sort order that used to
  /// come free from an autoincrementing id has to be stored explicitly now —
  /// "which category did I last use for this merchant" depends on it.
  final DateTime createdAt;

  final String? notes;

  /// Set when the receipt is in the trash; null when it is live.
  final DateTime? deletedAt;

  /// Absolute path to the photo on *this* device. Meaningless on any other
  /// device, which is what [photoUrl] is for.
  final String? photoPath;

  /// Download URL once the photo has been uploaded, so other devices (and
  /// this one after a reinstall) can still show it.
  final String? photoUrl;
}
