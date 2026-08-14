import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/utils/formatters.dart';

const _retention = Duration(days: 30);

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key, required this.repository});

  final ReceiptRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trash')),
      body: StreamBuilder<List<Receipt>>(
        stream: repository.watchTrash(),
        builder: (context, snapshot) {
          final receipts = snapshot.data ?? const [];
          if (receipts.isEmpty) {
            return const Center(child: Text('Trash is empty'));
          }
          return ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              final deletedAt = receipt.deletedAt!;
              final daysLeft =
                  _retention.inDays -
                  DateTime.now().difference(deletedAt).inDays;
              return ListTile(
                title: Text(receipt.merchant),
                subtitle: Text(
                  '${currencyFormat.format(receipt.amountYen)} · '
                  '${ReceiptCategory.fromName(receipt.category).label}\n'
                  'Deleted ${dateFormat.format(deletedAt)} · '
                  'auto-removes in ${daysLeft.clamp(0, _retention.inDays)}d',
                ),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () => repository.restore(receipt.id),
                  child: const Text('Restore'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
