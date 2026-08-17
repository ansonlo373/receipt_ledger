import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:receipt_ledger/models/ocr_line.dart';
import 'package:receipt_ledger/models/receipt_ocr_result.dart';
import 'package:receipt_ledger/services/receipt_line_grouping.dart';
import 'package:receipt_ledger/services/receipt_text_parser.dart';

Future<ReceiptOcrResult> recognizeReceipt(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
  try {
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );

    // Use each line's on-image position (not ML Kit's own block ordering)
    // to reconstruct receipt rows — a label and its value can be printed
    // side-by-side on a receipt but still come back as separate blocks.
    final lines = [
      for (final block in recognized.blocks)
        for (final line in block.lines)
          OcrLine(
            text: line.text,
            top: line.boundingBox.top,
            bottom: line.boundingBox.bottom,
            left: line.boundingBox.left,
          ),
    ];
    final reconstructedText = reconstructRowsAsText(lines);

    return parseReceiptText(reconstructedText);
  } finally {
    await recognizer.close();
  }
}
