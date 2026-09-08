import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:receipt_ledger/firebase_options.dart';
import 'package:receipt_ledger/screens/auth_gate.dart';
import 'package:receipt_ledger/services/auth_service.dart';
import 'package:receipt_ledger/theme/app_theme.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // On by default on mobile, but stated explicitly because the whole offline
  // story rests on it: writes queue locally and sync when back online.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  final themeController = ThemeController();
  await themeController.load();
  runApp(MyApp(themeController: themeController, authService: AuthService()));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.themeController,
    required this.authService,
  });

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
          // The repository is built inside the gate rather than here: it is
          // scoped to the signed-in account, which isn't known at startup.
          home: AuthGate(
            authService: authService,
            themeController: themeController,
          ),
        );
      },
    );
  }
}
