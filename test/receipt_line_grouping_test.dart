import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/ocr_line.dart';
import 'package:receipt_ledger/services/receipt_line_grouping.dart';

OcrLine _line(
  String text, {
  required double top,
  required double bottom,
  required double left,
}) {
  return OcrLine(text: text, top: top, bottom: bottom, left: left);
}

void main() {
  test('returns an empty string for no lines', () {
    expect(reconstructRowsAsText(const []), '');
  });

  test('a single line reconstructs to itself', () {
    final lines = [_line('合計', top: 100, bottom: 120, left: 10)];

    expect(reconstructRowsAsText(lines), '合計');
  });

  test('merges two lines with overlapping vertical ranges into one row, left-to-right', () {
    final lines = [
      _line('¥1,508', top: 105, bottom: 125, left: 200),
      _line('合計', top: 100, bottom: 120, left: 10),
    ];

    expect(reconstructRowsAsText(lines), '合計 ¥1,508');
  });

  test('keeps lines with non-overlapping vertical ranges on separate rows', () {
    final lines = [
      _line('合計', top: 100, bottom: 120, left: 10),
      _line('¥1,508', top: 200, bottom: 220, left: 10),
    ];

    expect(reconstructRowsAsText(lines), '合計\n¥1,508');
  });

  test('orders rows top-to-bottom regardless of input order', () {
    final lines = [
      _line('第二行', top: 200, bottom: 220, left: 10),
      _line('第一行', top: 100, bottom: 120, left: 10),
    ];

    expect(reconstructRowsAsText(lines), '第一行\n第二行');
  });

  test('groups three lines: two share a row, one is separate', () {
    final lines = [
      _line('小計', top: 300, bottom: 320, left: 10),
      _line('¥1,508', top: 105, bottom: 125, left: 200),
      _line('合計', top: 100, bottom: 120, left: 10),
    ];

    expect(reconstructRowsAsText(lines), '合計 ¥1,508\n小計');
  });
}
