import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/receipt_ocr_result.dart';
import 'package:receipt_ledger/services/gemini_rescan_service.dart';

void main() {
  test('reads merchant, amount and date from a well-formed response', () {
    final result = parseGeminiRescanResponse({
      'merchant': 'SEIYU',
      'amount': 1628,
      'date': '2026-08-17',
    });

    expect(result.merchant, 'SEIYU');
    expect(result.amountYen, 1628);
    expect(result.date, DateTime(2026, 8, 17));
    expect(result.source, OcrSource.geminiOnline);
  });

  test('treats the agreed "could not read" values as nothing found', () {
    // The function asks for empty string / 0 rather than a guess, so those
    // must not become a merchant called "" or an amount of ¥0.
    final result = parseGeminiRescanResponse({
      'merchant': '',
      'amount': 0,
      'date': '',
    });

    expect(result.merchant, isNull);
    expect(result.amountYen, isNull);
    expect(result.date, isNull);
  });

  test('treats missing fields as nothing found', () {
    final result = parseGeminiRescanResponse({});

    expect(result.merchant, isNull);
    expect(result.amountYen, isNull);
    expect(result.date, isNull);
  });

  test('trims surrounding whitespace from the merchant', () {
    final result = parseGeminiRescanResponse({'merchant': '  SEIYU  '});

    expect(result.merchant, 'SEIYU');
  });

  test('accepts an amount that arrives as a number with a decimal part', () {
    // JSON numbers can decode as double even when the schema says integer.
    final result = parseGeminiRescanResponse({'amount': 1628.0});

    expect(result.amountYen, 1628);
  });

  test('accepts an amount that arrives as a string', () {
    final result = parseGeminiRescanResponse({'amount': '1628'});

    expect(result.amountYen, 1628);
  });

  test('ignores an unparseable amount rather than throwing', () {
    final result = parseGeminiRescanResponse({'amount': 'about ¥1,600'});

    expect(result.amountYen, isNull);
  });

  test('ignores a negative amount', () {
    final result = parseGeminiRescanResponse({'amount': -500});

    expect(result.amountYen, isNull);
  });

  test('ignores an unparseable date rather than throwing', () {
    final result = parseGeminiRescanResponse({'date': 'last Tuesday'});

    expect(result.date, isNull);
  });

  test('ignores an impossible date', () {
    final result = parseGeminiRescanResponse({'date': '2026-13-45'});

    expect(result.date, isNull);
  });

  test('offers no amount candidates', () {
    // Unlike the on-device parser, which guesses among several numbers and
    // needs the user to disambiguate, this returns one considered answer.
    final result = parseGeminiRescanResponse({'amount': 1628});

    expect(result.amountCandidates, isEmpty);
  });
}
