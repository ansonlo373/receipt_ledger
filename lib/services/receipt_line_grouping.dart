import 'package:receipt_ledger/models/ocr_line.dart';

/// Reconstructs receipt rows from OCR lines using their on-image position,
/// instead of trusting the OCR engine's own block/line ordering — which for
/// multi-column receipts (label on the left, value on the right) can split a
/// label from its value even though they're printed on the same physical
/// row. Lines whose vertical spans overlap are treated as one row and
/// ordered left-to-right; separate rows are ordered top-to-bottom.
String reconstructRowsAsText(List<OcrLine> lines) {
  if (lines.isEmpty) return '';

  final sorted = [...lines]..sort((a, b) => a.top.compareTo(b.top));

  final rows = <List<OcrLine>>[];
  var rowTop = sorted.first.top;
  var rowBottom = sorted.first.bottom;
  var currentRow = [sorted.first];

  for (final line in sorted.skip(1)) {
    final overlapsCurrentRow = line.top < rowBottom && line.bottom > rowTop;
    if (overlapsCurrentRow) {
      currentRow.add(line);
      rowTop = rowTop < line.top ? rowTop : line.top;
      rowBottom = rowBottom > line.bottom ? rowBottom : line.bottom;
    } else {
      rows.add(currentRow);
      currentRow = [line];
      rowTop = line.top;
      rowBottom = line.bottom;
    }
  }
  rows.add(currentRow);

  return rows
      .map(
        (row) => (row..sort((a, b) => a.left.compareTo(b.left)))
            .map((line) => line.text)
            .join(' '),
      )
      .join('\n');
}
