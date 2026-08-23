import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/screens/receipt_list_screen.dart';

import 'fake_receipt_repository.dart';

void main() {
  testWidgets('shows empty state message when there are no receipts', (
    WidgetTester tester,
  ) async {
    final repository = FakeReceiptRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptListScreen(
          repository: repository,
          photoSyncService: fakePhotoSyncService(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No receipts yet'), findsOneWidget);
  });

  testWidgets('lists each receipt\'s merchant and formatted amount', (
    WidgetTester tester,
  ) async {
    final repository = FakeReceiptRepository([
      Receipt(
        id: '1',
        merchant: 'Trader Joe\'s',
        amountYen: 1240,
        date: DateTime(2026, 8, 10),
        category: 'groceries',
        createdAt: DateTime(2026, 8, 10),
        notes: null,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptListScreen(
          repository: repository,
          photoSyncService: fakePhotoSyncService(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No receipts yet'), findsNothing);
    expect(find.text('Trader Joe\'s'), findsOneWidget);
    expect(find.text('¥1,240'), findsOneWidget);
  });
}
