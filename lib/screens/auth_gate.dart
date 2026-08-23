import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/firestore_receipt_repository.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/screens/dashboard_screen.dart';
import 'package:receipt_ledger/screens/sign_in_screen.dart';
import 'package:receipt_ledger/services/auth_service.dart';
import 'package:receipt_ledger/services/photo_sync_service.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';

/// Decides between the sign-in screen and the app itself, and owns the
/// per-account repository, so no other screen has to think about who is
/// signed in.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.themeController,
  });

  final AuthService authService;
  final ThemeController themeController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Kept between rebuilds so the Firestore listeners underneath aren't torn
  /// down and recreated on every frame; replaced only when the account does.
  String? _uid;
  ReceiptRepository? _repository;
  PhotoSyncService? _photoSyncService;

  void _buildServicesFor(String uid) {
    if (_repository != null && _uid == uid) return;

    final repository = FirestoreReceiptRepository(
      firestore: FirebaseFirestore.instance,
      uid: uid,
    );
    _uid = uid;
    _repository = repository;
    final photoSync = PhotoSyncService(repository: repository, uid: uid);
    _photoSyncService = photoSync;
    // Old trash is cleared once per sign-in, in the background — nothing on
    // screen waits for it.
    unawaited(_purgeTrash(repository, photoSync));
  }

  /// Clears expired trash, then the photos belonging to it — otherwise those
  /// files would sit in storage forever with no receipt pointing at them.
  Future<void> _purgeTrash(
    ReceiptRepository repository,
    PhotoSyncService photoSync,
  ) async {
    try {
      final purged = await repository.purgeExpiredTrash();
      for (final receipt in purged) {
        await photoSync.deletePhoto(
          receiptId: receipt.id,
          localPath: receipt.photoPath,
        );
      }
    } catch (_) {
      // Housekeeping only; next sign-in tries again.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges(),
      builder: (context, snapshot) {
        // The first event carries the restored session, so waiting here
        // avoids flashing the sign-in screen on every launch.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          _uid = null;
          _repository = null;
          _photoSyncService = null;
          return SignInScreen(authService: widget.authService);
        }

        _buildServicesFor(user.uid);
        return DashboardScreen(
          repository: _repository!,
          photoSyncService: _photoSyncService!,
          themeController: widget.themeController,
          authService: widget.authService,
        );
      },
    );
  }
}
