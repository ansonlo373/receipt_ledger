import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/screens/dashboard_screen.dart';
import 'package:receipt_ledger/screens/sign_in_screen.dart';
import 'package:receipt_ledger/services/auth_service.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';

/// Decides between the sign-in screen and the app itself, so no other screen
/// has to ask whether anyone is signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.repository,
    required this.themeController,
  });

  final AuthService authService;
  final ReceiptRepository repository;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        // The first event carries the restored session, so waiting here
        // avoids showing the sign-in screen for a frame on every launch.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return SignInScreen(authService: authService);
        }

        return DashboardScreen(
          repository: repository,
          themeController: themeController,
          authService: authService,
        );
      },
    );
  }
}
