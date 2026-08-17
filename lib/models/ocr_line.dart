class OcrLine {
  const OcrLine({
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
  });

  final String text;
  final double top;
  final double bottom;
  final double left;
}
