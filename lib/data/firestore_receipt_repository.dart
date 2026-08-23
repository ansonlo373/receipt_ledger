import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

/// Receipts stored per account at `/users/{uid}/receipts/{id}`.
///
/// Scoping by uid in the path (rather than a field on each document) is what
/// lets the security rules be a single line, and keeps one account's data
/// unreachable from another's.
///
/// Firestore's own on-disk cache makes reads and writes work offline, so
/// there is deliberately no second local database behind this.
class FirestoreReceiptRepository implements ReceiptRepository {
  FirestoreReceiptRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _receipts = firestore
           .collection('users')
           .doc(uid)
           .collection('receipts');

  final CollectionReference<Map<String, dynamic>> _receipts;

  @override
  Stream<List<Receipt>> watchAll() {
    return _receipts
        .where('deletedAt', isNull: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map(_toReceipts);
  }

  @override
  Stream<List<Receipt>> watchTrash() {
    return _receipts
        .where('deletedAt', isNull: false)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map(_toReceipts);
  }

  @override
  Future<String> add({
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
    String? photoPath,
  }) async {
    // doc() with no id generates one locally, with no network call, so the
    // id is available even offline. Using add() instead would mean waiting
    // for the server to hand one back.
    final doc = _receipts.doc();
    _write(doc.set({
      'merchant': merchant,
      'amountYen': amountYen,
      'date': Timestamp.fromDate(date),
      'category': category.name,
      'notes': notes,
      'photoPath': photoPath,
      'photoUrl': null,
      // Written as an explicit null rather than left out: Firestore's
      // `isNull: true` filter only matches documents where the field is
      // present and null, so omitting it would hide the receipt from
      // watchAll() entirely.
      'deletedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    }));
    return doc.id;
  }

  @override
  Future<void> update({
    required String id,
    required String merchant,
    required int amountYen,
    required DateTime date,
    required ReceiptCategory category,
    String? notes,
    String? photoPath,
  }) async {
    // Deliberately does not touch createdAt, deletedAt or photoUrl — editing
    // a receipt should not change when it was created, un-delete it, or undo
    // a photo upload that finished in the background.
    _write(_receipts.doc(id).update({
      'merchant': merchant,
      'amountYen': amountYen,
      'date': Timestamp.fromDate(date),
      'category': category.name,
      'notes': notes,
      'photoPath': photoPath,
    }));
  }

  @override
  Future<void> setPhotoUrl({
    required String id,
    required String photoUrl,
  }) async {
    _write(_receipts.doc(id).update({'photoUrl': photoUrl}));
  }

  @override
  Future<void> softDelete(String id) async {
    _write(_receipts.doc(id).update({
      'deletedAt': FieldValue.serverTimestamp(),
    }));
  }

  @override
  Future<void> restore(String id) async {
    // Back to an explicit null, not FieldValue.delete(), for the same reason
    // add() writes one: a missing field is invisible to `isNull: true`.
    _write(_receipts.doc(id).update({'deletedAt': null}));
  }

  @override
  Future<void> purgeExpiredTrash({
    Duration retention = const Duration(days: 30),
  }) async {
    final cutoff = DateTime.now().subtract(retention);
    final expired = await _receipts
        .where('deletedAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    for (final doc in expired.docs) {
      _write(doc.reference.delete());
    }
  }

  /// Hands a write to Firestore without waiting for the server.
  ///
  /// Firestore only completes a write's future once the server acknowledges
  /// it, which offline means never — but the local cache is updated straight
  /// away and the write is persisted to disk and replayed on reconnect. So
  /// awaiting would freeze the UI offline while buying nothing: the data is
  /// already safe. Failures are swallowed rather than left to surface as
  /// unhandled errors, since the SDK's own retry is the recovery path.
  void _write(Future<void> pending) {
    pending.catchError((Object _) {});
  }

  List<Receipt> _toReceipts(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return [for (final doc in snapshot.docs) _toReceipt(doc)];
  }

  Receipt _toReceipt(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Receipt(
      id: doc.id,
      merchant: data['merchant'] as String? ?? '',
      amountYen: (data['amountYen'] as num?)?.toInt() ?? 0,
      date: _toDate(data['date']) ?? DateTime.now(),
      category: data['category'] as String? ?? 'other',
      // A receipt written offline has no server timestamp until it syncs, so
      // fall back to its receipt date to keep ordering sane in the meantime.
      createdAt: _toDate(data['createdAt']) ?? _toDate(data['date']) ??
          DateTime.now(),
      notes: data['notes'] as String?,
      deletedAt: _toDate(data['deletedAt']),
      photoPath: data['photoPath'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
