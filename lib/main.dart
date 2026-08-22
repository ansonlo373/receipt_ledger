import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/firebase_options.dart';
import 'package:receipt_ledger/screens/auth_gate.dart';
import 'package:receipt_ledger/services/auth_service.dart';
import 'package:receipt_ledger/theme/app_theme.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final themeController = ThemeController();
  await themeController.load();
  final repository = DriftReceiptRepository(ReceiptsDatabase());
  unawaited(repository.purgeExpiredTrash());
  runApp(
    MyApp(
      repository: repository,
      themeController: themeController,
      authService: AuthService(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.repository,
    required this.themeController,
    required this.authService,
  });

  final ReceiptRepository repository;
  final ThemeController themeController;
  final AuthService authService;

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
          home: AuthGate(
            authService: authService,
            repository: repository,
            themeController: themeController,
          ),
        );
      },
    );
  }
}
