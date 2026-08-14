import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/month_summary.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/screens/receipt_form_screen.dart';
import 'package:receipt_ledger/screens/receipt_list_screen.dart';
import 'package:receipt_ledger/screens/settings_screen.dart';
import 'package:receipt_ledger/theme/app_theme.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';
import 'package:receipt_ledger/utils/formatters.dart';

const _categoryColors = {
  ReceiptCategory.groceries: Color(0xFF2F4B6E),
  ReceiptCategory.dining: Color(0xFFB23A2E),
  ReceiptCategory.transport: Color(0xFF8AA6C2),
  ReceiptCategory.utilities: Color(0xFFC9A15A),
  ReceiptCategory.shopping: Color(0xFF4F7D57),
  ReceiptCategory.other: Color(0xFF9AA3AC),
};

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.themeController,
  });

  final ReceiptRepository repository;
  final ThemeController themeController;

  void _openManualEntry(BuildContext context, {Receipt? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ReceiptFormScreen(repository: repository, existing: existing),
      ),
    );
  }

  void _openList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReceiptListScreen(repository: repository),
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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    SettingsScreen(themeController: themeController),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Receipt>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          final receipts = snapshot.data ?? const [];
          final summary = MonthSummary.of(receipts, DateTime.now());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: () => _openManualEntry(context),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan a receipt'),
              ),
              TextButton(
                onPressed: () => _openManualEntry(context),
                child: const Text('＋ Add manually'),
              ),
              const SizedBox(height: 8),
              _MonthCard(summary: summary),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => _openList(context),
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (summary.recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No receipts yet')),
                )
              else
                for (final receipt in summary.recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(receipt.merchant),
                    subtitle: Text(
                      '${dateFormat.format(receipt.date)} · '
                      '${ReceiptCategory.fromName(receipt.category).label}',
                    ),
                    trailing: Text(currencyFormat.format(receipt.amountYen)),
                    onTap: () =>
                        _openManualEntry(context, existing: receipt),
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
            Text(
              monthFormat.format(DateTime.now()),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            if (summary.topCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final category in summary.topCategories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          category.category.label,
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
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            color: _categoryColors[category.category],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 64,
                        child: Text(
                          currencyFormat.format(category.amountYen),
                          textAlign: TextAlign.right,
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
