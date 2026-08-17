enum OcrSource {
  onDeviceMlKit;

  String get label {
    switch (this) {
      case OcrSource.onDeviceMlKit:
        return 'Read on-device';
    }
  }
}

class ReceiptOcrResult {
  const ReceiptOcrResult({
    required this.source,
    this.merchant,
    this.amountYen,
    this.amountCandidates = const [],
    this.date,
  });

  final OcrSource source;
  final String? merchant;
  final int? amountYen;

  /// Every distinct ¥/円-marked amount found on the receipt, ranked by how
  /// often it repeats (then by value). When this has more than one entry,
  /// the amount is genuinely ambiguous — the UI should let the user pick
  /// rather than trust [amountYen] alone.
  final List<int> amountCandidates;

  final DateTime? date;
}
