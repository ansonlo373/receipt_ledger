import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/month_summary.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/models/receipt_ocr_result.dart';
import 'package:receipt_ledger/screens/category_screen.dart';
import 'package:receipt_ledger/screens/receipt_form_screen.dart';
import 'package:receipt_ledger/screens/receipt_list_screen.dart';
import 'package:receipt_ledger/screens/settings_screen.dart';
import 'package:receipt_ledger/services/photo_storage.dart';
import 'package:receipt_ledger/services/receipt_ocr.dart';
import 'package:receipt_ledger/theme/app_theme.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';
import 'package:receipt_ledger/utils/category_colors.dart';
import 'package:receipt_ledger/services/auth_service.dart';
import 'package:receipt_ledger/utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.themeController,
    required this.authService,
  });

  final ReceiptRepository repository;
  final ThemeController themeController;
  final AuthService authService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200) {
      _shiftMonth(1);
    } else if (velocity > 200) {
      _shiftMonth(-1);
    }
  }

  void _openManualEntry({Receipt? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReceiptFormScreen(
          repository: widget.repository,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _scanReceipt() async {
    // DocumentScanner's own UI covers both camera capture (with live edge
    // detection) and gallery import (isGalleryImport) in one flow, then lets
    // the user confirm/adjust the crop before returning the cropped image —
    // so no separate camera-vs-gallery picker or manual cropper is needed.
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: {DocumentFormat.jpeg},
        mode: ScannerMode.filter,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );

    DocumentScanningResult? result;
    try {
      result = await scanner.scanDocument();
    } catch (_) {
      // User cancelled the scan, or the Play Services scanner module isn't
      // available — either way, just return to the dashboard.
      return;
    } finally {
      scanner.close();
    }

    final images = result.images ?? const [];
    if (images.isEmpty) return;

    final savedPath = await savePhotoLocally(images.first);
    if (!mounted) return;

    // Text recognition can take a moment on-device; show a lightweight,
    // non-dismissible progress indicator rather than leaving the screen
    // looking frozen.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    ReceiptOcrResult? ocrResult;
    try {
      ocrResult = await recognizeReceipt(savedPath);
    } catch (_) {
      // OCR is a convenience, not a requirement — fall through to a blank
      // (but still photo-attached) form rather than blocking the flow.
      ocrResult = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss the progress dialog

    final foundAnything =
        ocrResult != null &&
        (ocrResult.merchant != null ||
            ocrResult.amountYen != null ||
            ocrResult.date != null);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReceiptFormScreen(
          repository: widget.repository,
          initialPhotoPath: savedPath,
          initialMerchant: ocrResult?.merchant,
          initialAmountYen: ocrResult?.amountYen,
          initialAmountCandidates: ocrResult?.amountCandidates ?? const [],
          initialDate: ocrResult?.date,
          ocrSource: foundAnything ? ocrResult?.source : null,
        ),
      ),
    );
  }

  void _openList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReceiptListScreen(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Category breakdown',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    CategoryScreen(repository: widget.repository),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    SettingsScreen(
                      themeController: widget.themeController,
                      authService: widget.authService,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Receipt>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          final receipts = snapshot.data ?? const [];
          final summary = MonthSummary.of(receipts, _month);
          // Independent of the swipeable month card below: always the most
          // recently added receipts overall, not scoped to _month.
          final recent = ([
            ...receipts,
          ]..sort((a, b) => b.date.compareTo(a.date))).take(3).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: _scanReceipt,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan a receipt'),
              ),
              TextButton(
                onPressed: () => _openManualEntry(),
                child: const Text('＋ Add manually'),
              ),
              const SizedBox(height: 8),
              // Swipe is scoped to just this month-card area so it doesn't
              // fight scrolling/tapping in the Recent list below.
              GestureDetector(
                onHorizontalDragEnd: _onHorizontalSwipe,
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _shiftMonth(-1),
                        ),
                        Text(
                          monthFormat.format(_month),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _shiftMonth(1),
                        ),
                      ],
                    ),
                    _MonthCard(summary: summary),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: _openList,
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No receipts yet')),
                )
              else
                for (final receipt in recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(receipt.merchant),
                    subtitle: Text(
                      '${dateFormat.format(receipt.date)} · '
                      '${ReceiptCategory.fromName(receipt.category).label}',
                    ),
                    trailing: Text(currencyFormat.format(receipt.amountYen)),
                    onTap: () => _openManualEntry(existing: receipt),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final diff = summary.totalYen - summary.previousMonthTotalYen;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  currencyFormat.format(summary.totalYen),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (diff != 0)
                  Text(
                    '${diff > 0 ? '▲' : '▼'} ${currencyFormat.format(diff.abs())} vs last month',
                    style: TextStyle(
                      color: diff > 0
                          ? colorScheme.error
                          : (Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.sageDark
                                : AppTheme.sageLight),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            if (summary.allCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final category in summary.allCategories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          category.category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: summary.totalYen == 0
                                ? 0
                                : category.amountYen / summary.totalYen,
                            minHeight: 6,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            color: categoryColors[category.category],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 64,
                        child: Text(
                          currencyFormat.format(category.amountYen),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
