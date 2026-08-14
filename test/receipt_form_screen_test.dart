import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ledger/screens/receipt_form_screen.dart';

import 'fake_receipt_repository.dart';

void main() {
  testWidgets(
    'shows a validation error and does not save when merchant is empty',
    (WidgetTester tester) async {
      final repository = FakeReceiptRepository();

      await tester.pumpWidget(
        MaterialApp(home: ReceiptFormScreen(repository: repository)),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a merchant'), findsOneWidget);
      expect(await repository.watchAll().first, isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
