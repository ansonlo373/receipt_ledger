import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/screens/receipt_form_screen.dart';
import 'package:receipt_ledger/utils/formatters.dart';

class ReceiptListScreen extends StatelessWidget {
  const ReceiptListScreen({super.key, required this.repository});

  final ReceiptRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: StreamBuilder<List<Receipt>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          final receipts = snapshot.data ?? const [];
          if (receipts.isEmpty) {
            return const Center(child: Text('No receipts yet'));
          }
          return ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              return Dismissible(
                key: ValueKey(receipt.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) => repository.delete(receipt.id),
                child: ListTile(
                  title: Text(receipt.merchant),
                  subtitle: Text(
                    '${dateFormat.format(receipt.date)} · '
                    '${ReceiptCategory.fromName(receipt.category).label}',
                  ),
                  trailing: Text(currencyFormat.format(receipt.amountYen)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ReceiptFormScreen(
                        repository: repository,
                        existing: receipt,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReceiptFormScreen(repository: repository),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
