import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:receipt_ledger/models/receipt_ocr_result.dart';
import 'package:receipt_ledger/services/image_resize.dart';

/// Must match the region the function is deployed to. `FirebaseFunctions
/// .instance` defaults to us-central1 regardless of where the function
/// actually lives, and a mismatch surfaces as a bare NOT_FOUND rather than
/// anything that points at the region.
const _functionsRegion = 'us-central1';

/// Turns the Cloud Function's JSON into a result the form can use.
///
/// Deliberately forgiving: a model can return a field in an unexpected shape
/// even with a response schema, and a rescan that quietly finds nothing is
/// much better than one that throws in the user's face. The function is asked
/// to send an empty string (or 0) rather than guess, so those mean "couldn't
/// read it", not a real value.
ReceiptOcrResult parseGeminiRescanResponse(Map<String, dynamic> json) {
  return ReceiptOcrResult(
    source: OcrSource.geminiOnline,
    merchant: _parseMerchant(json['merchant']),
    amountYen: _parseAmount(json['amount']),
    date: _parseDate(json['date']),
  );
}

String? _parseMerchant(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _parseAmount(Object? value) {
  final amount = switch (value) {
    int i => i,
    double d => d.round(),
    String s => int.tryParse(s.trim()),
    _ => null,
  };
  // 0 is the agreed "unreadable" signal, and a negative total is nonsense.
  if (amount == null || amount <= 0) return null;
  return amount;
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return null;
  // DateTime.tryParse accepts some out-of-range values by rolling over
  // (month 13 becomes January of the next year), so check it round-trips.
  final asDate = '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return value.trim().startsWith(asDate) ? parsed : null;
}

/// Sends the receipt photo to the Cloud Function, which reads it with Gemini
/// and sends back the fields it found.
///
/// The photo is resized first: Gemini prices images by resolution, so a raw
/// camera photo would cost several times as much for detail the model cannot
/// use anyway.
Future<ReceiptOcrResult> rescanWithGemini(
  String imagePath, {
  FirebaseFunctions? functions,
}) async {
  final bytes = await readResizedJpeg(imagePath);
  final callable = (functions ??
          FirebaseFunctions.instanceFor(region: _functionsRegion))
      .httpsCallable('rescanReceipt');

  final response = await callable.call<Map<String, dynamic>>({
    'imageBase64': base64Encode(bytes),
  });

  return parseGeminiRescanResponse(Map<String, dynamic>.from(response.data));
}
