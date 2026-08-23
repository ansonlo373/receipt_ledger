import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/receipt_ocr_result.dart';
import 'package:receipt_ledger/services/receipt_text_parser.dart';

void main() {
  test('guesses the merchant from the first non-empty line', () {
    final result = parseReceiptText('セブン-イレブン\n東京都渋谷区\n合計 ¥500');

    expect(result.merchant, 'セブン-イレブン');
  });

  test('returns a null merchant for blank text', () {
    final result = parseReceiptText('   \n  ');

    expect(result.merchant, isNull);
  });

  test(
    'prefers the amount on a line with a total keyword over other numbers',
    () {
      final result = parseReceiptText(
        'ローソン\n'
        'おにぎり 150\n'
        'お茶 120\n'
        '合計 ¥270',
      );

      expect(result.amountYen, 270);
    },
  );

  test('recognizes an English TOTAL keyword case-insensitively', () {
    final result = parseReceiptText('Starbucks\nCoffee 500\nTOTAL: 500');

    expect(result.amountYen, 500);
  });

  test('strips comma thousands separators from the amount', () {
    final result = parseReceiptText('Store\nItem 1,000\n合計 1,200円');

    expect(result.amountYen, 1200);
  });

  test(
    'falls back to the largest number when no total keyword line exists',
    () {
      final result = parseReceiptText('Store\n120\n45\n300');

      expect(result.amountYen, 300);
    },
  );

  test('prefers a repeated yen-marked amount over a larger one-off number', () {
    // Mirrors a real receipt: the actual total is printed several times
    // (item summary, card confirmation, authorization slip) while an
    // unrelated big number (registration/card/transaction id) appears once
    // and is much larger in raw digit count.
    final result = parseReceiptText(
      'Store\n'
      '登録番号 T8011503002037\n'
      '育計\n' // OCR misread of 合計 — the keyword match should fail here
      '¥1,508\n'
      'クレジット支払\n'
      '¥1,508\n'
      '承認No:015889\n'
      '¥1,508',
    );

    expect(result.amountYen, 1508);
  });

  test('breaks a tie between equally-repeated yen amounts by picking the larger one', () {
    final result = parseReceiptText('Store\n¥100\n¥100\n¥900\n¥900');

    expect(result.amountYen, 900);
  });

  test(
    'handles a stray space after the thousands comma (real OCR artifact)',
    () {
      // ML Kit has been observed reading "¥1,508" as "¥1, 508" on real
      // receipts — the comma-grouping regex must tolerate that space.
      final result = parseReceiptText('Store\n合計 ¥1, 508');

      expect(result.amountYen, 1508);
    },
  );

  test('prefers a repeated yen amount even when comma-space OCR artifacts are present', () {
    final result = parseReceiptText(
      'Store\n'
      '登録番号 T8011503002037\n'
      '育計\n'
      '¥1, 508\n'
      'クレジット支払\n'
      '¥1, 508\n'
      '承認No:015889\n'
      '¥1, 508',
    );

    expect(result.amountYen, 1508);
  });

  test('trusts a comma-grouped number on the keyword row even without a '
      'currency marker, over a plain (non-grouped) unmarked number on that '
      'same row', () {
    // Real receipt case: OCR misread the ¥ before the total as a stray
    // leading digit ("41,628" instead of "¥1,628"), so the correct value
    // never carries an explicit ¥/円 marker at all — but it's still the
    // last comma-grouped ("looks like a formatted amount") token on the
    // 合計 row, which is what should win. "8%" and "6点" are plain
    // ungrouped numbers and must NOT be picked instead. Other, unrelated
    // ¥-marked amounts appear elsewhere on the receipt (item prices) —
    // the keyword row's own number must win over those, not just over
    // this row's own unmarked noise.
    final result = parseReceiptText(
      'Store\n'
      '¥169\n'
      '¥169\n'
      '楽天ポイントカード: 合計 8% 6点 41,628 1,628',
    );

    expect(result.amountYen, 1628);
  });

  test('falls back to a repeated currency-marked amount when the keyword row '
      'has no comma-grouped number at all (keyword itself misread)', () {
    final result = parseReceiptText(
      'Store\n'
      '登録番号 T8011503002037\n'
      '育計\n' // OCR misread of 合計 — the keyword match should fail here
      '¥1,508\n'
      'クレジット支払\n'
      '¥1,508\n'
      '承認No:015889\n'
      '¥1,508',
    );

    expect(result.amountYen, 1508);
  });

  test('lists multiple distinct yen-marked amounts as candidates, ranked by frequency then value', () {
    final result = parseReceiptText('Store\n¥169\n¥169\n¥1,508\n¥449');

    expect(result.amountCandidates, [169, 1508, 449]);
  });

  test('returns a single-entry candidate list when only one yen-marked amount exists', () {
    final result = parseReceiptText('Store\n合計 ¥500');

    expect(result.amountCandidates, [500]);
  });

  test('returns an empty candidate list when no yen-marked amounts exist', () {
    final result = parseReceiptText('Store\n120\n300');

    expect(result.amountCandidates, isEmpty);
  });

  test(
    'includes comma-grouped amounts without a currency marker as candidates',
    () {
      final result = parseReceiptText('Store\n1,628\n8%\n6点');

      expect(result.amountCandidates, [1628]);
    },
  );

  test('returns a null amount when no numbers are present', () {
    final result = parseReceiptText('Store\nThank you for visiting');

    expect(result.amountYen, isNull);
  });

  test('parses a yyyy/mm/dd date', () {
    final result = parseReceiptText('Store\n2026/08/15\n合計 500');

    expect(result.date, DateTime(2026, 8, 15));
  });

  test('parses a yyyy年mm月dd日 date', () {
    final result = parseReceiptText('Store\n2026年8月15日\n合計 500');

    expect(result.date, DateTime(2026, 8, 15));
  });

  test(
    'tolerates stray whitespace around date separators (row-merge artifact)',
    () {
      // Row reconstruction can join what was originally "2026年8月17日" into
      // "2026年 8月17日" when the year and month/day were separate OCR
      // elements on the same visual row.
      final result = parseReceiptText('Store\n2026年 8月17日\n合計 500');

      expect(result.date, DateTime(2026, 8, 17));
    },
  );

  test('returns a null date when no date pattern is present', () {
    final result = parseReceiptText('Store\n合計 500');

    expect(result.date, isNull);
  });

  test('marks the result as coming from the on-device ML Kit source', () {
    final result = parseReceiptText('Store\n合計 500');

    expect(result.source, OcrSource.onDeviceMlKit);
  });
}
