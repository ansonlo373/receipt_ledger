import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/screens/dashboard_screen.dart';
import 'package:receipt_ledger/theme/app_theme.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.load();
  runApp(
    MyApp(
      repository: DriftReceiptRepository(ReceiptsDatabase()),
      themeController: themeController,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.repository,
    required this.themeController,
  });

  final ReceiptRepository repository;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Receipt Ledger',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: DashboardScreen(
            repository: repository,
            themeController: themeController,
          ),
        );
      },
    );
  }
}
