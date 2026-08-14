import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/screens/receipt_list_screen.dart';

void main() {
  runApp(MyApp(repository: DriftReceiptRepository(ReceiptsDatabase())));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository});

  final ReceiptRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Receipt Ledger',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: ReceiptListScreen(repository: repository),
    );
  }
}
