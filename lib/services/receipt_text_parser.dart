import 'package:receipt_ledger/models/receipt_ocr_result.dart';

final _totalKeywordPattern = RegExp(r'(合計|total|amount)', caseSensitive: false);
// Matches grouped-thousands numbers (with an optional stray space after the
// comma, e.g. "1, 508" — an OCR artifact observed on real receipts) or a
// plain digit run when there's no comma grouping at all.
const _numberBody = r'\d{1,3}(?:,\s?\d{3})+|\d+';
// Comma-grouped only (no plain-digit-run fallback) — used as an "amount
// shaped" signal on its own, without requiring a currency marker.
const _groupedNumberBody = r'\d{1,3}(?:,\s?\d{3})+';
final _numberPattern = RegExp(_numberBody);
// A number counts as "amount-like" if it's either ¥/円-marked (any grouping,
// since small amounts like ¥500 aren't comma-grouped at all) OR simply
// comma-grouped with no marker at all. The latter matters because OCR
// regularly misreads the ¥ right before a total as a stray digit or letter
// (e.g. "¥1,628" → "41,628" or "t1,628") — requiring an explicit marker
// would silently discard the correct amount every time that happens.
final _amountLikeNumberPattern = RegExp(
  '¥\\s?($_numberBody)|($_groupedNumberBody)(?:\\s?円)?',
);
// \s? around each separator tolerates row-merge artifacts like
// "2026年 8月17日" (a stray space where two OCR elements got joined).
final _fullDatePattern = RegExp(
  r'(\d{4})\s?[/\-年]\s?(\d{1,2})\s?[/\-月]\s?(\d{1,2})\s?日?',
);

int? _parseAmount(String digits) =>
    int.tryParse(digits.replaceAll(RegExp(r'[,\s]'), ''));

ReceiptOcrResult parseReceiptText(String rawText) {
  final lines = rawText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return ReceiptOcrResult(
    source: OcrSource.onDeviceMlKit,
    merchant: lines.isEmpty ? null : lines.first,
    amountYen: _guessAmount(lines),
    amountCandidates: _rankedAmountLikeNumbers(lines),
    date: _guessDate(lines),
  );
}

int? _guessAmount(List<String> lines) {
  // Tier 1: a total-keyword line that also has an amount-like number
  // (¥/円-marked, or simply comma-grouped) — the strongest signal, since
  // it's both near the keyword and shaped like a formatted amount.
  // Deliberately NOT "any number on the keyword line": row reconstruction
  // can merge a genuine 合計 label onto the same row as unrelated, plain
  // (ungrouped, unmarked) numbers like loyalty points or percentages —
  // trusting the last number of any kind on that contaminated row picks
  // the wrong one.
  for (final line in lines) {
    if (_totalKeywordPattern.hasMatch(line)) {
      final amount = _lastAmountLikeNumberIn(line);
      if (amount != null) return amount;
    }
  }

  // Tier 2: OCR sometimes misreads the keyword itself (合計 → 育計), or the
  // real total just never lands on the same row as the keyword. Before
  // guessing blindly, prefer whichever amount-like number repeats most
  // often across the whole receipt: real totals tend to print multiple
  // times (item summary, card confirmation, authorization slip), while
  // unrelated large numbers are rarely both amount-shaped and repeated.
  final rankedCandidates = _rankedAmountLikeNumbers(lines);
  if (rankedCandidates.isNotEmpty) {
    return rankedCandidates.first;
  }

  // Tier 3: a keyword line exists but has no amount-like number at all —
  // fall back to the last number on it, of any shape.
  for (final line in lines) {
    if (_totalKeywordPattern.hasMatch(line)) {
      final amount = _lastNumberIn(line);
      if (amount != null) return amount;
    }
  }

  // Tier 4: no keyword line and no repeated amount-like number — last
  // resort, the largest number anywhere on the receipt.
  int? largest;
  for (final line in lines) {
    for (final match in _numberPattern.allMatches(line)) {
      final amount = _parseAmount(match.group(0)!);
      if (amount != null && (largest == null || amount > largest)) {
        largest = amount;
      }
    }
  }
  return largest;
}

/// Every distinct amount-like number found (¥/円-marked, or comma-grouped
/// with no marker at all), ranked by how often it repeats (ties broken by
/// larger value first).
List<int> _rankedAmountLikeNumbers(List<String> lines) {
  final counts = <int, int>{};
  for (final line in lines) {
    for (final match in _amountLikeNumberPattern.allMatches(line)) {
      final digits = match.group(1) ?? match.group(2)!;
      final amount = _parseAmount(digits);
      if (amount != null) counts[amount] = (counts[amount] ?? 0) + 1;
    }
  }
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : b.key.compareTo(a.key);
    });
  return [for (final entry in ranked) entry.key];
}

int? _lastAmountLikeNumberIn(String line) {
  final matches = _amountLikeNumberPattern.allMatches(line).toList();
  if (matches.isEmpty) return null;
  final digits = matches.last.group(1) ?? matches.last.group(2)!;
  return _parseAmount(digits);
}

int? _lastNumberIn(String line) {
  final matches = _numberPattern.allMatches(line).toList();
  if (matches.isEmpty) return null;
  return _parseAmount(matches.last.group(0)!);
}

DateTime? _guessDate(List<String> lines) {
  for (final line in lines) {
    final match = _fullDatePattern.firstMatch(line);
    if (match == null) continue;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    return DateTime(year, month, day);
  }
  return null;
}
