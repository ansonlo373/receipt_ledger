import 'package:flutter/material.dart';
import 'package:receipt_ledger/services/auth_service.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.authService,
  });

  final ThemeController themeController;
  final AuthService authService;

  Future<void> _confirmSignOut(BuildContext context) async {
    final signOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your receipts stay in your account. Sign back in to reach them '
          'again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (signOut != true) return;
    await authService.signOut();
    // AuthGate swaps in the sign-in screen on its own once the auth state
    // changes, so this screen only needs to get out of the way.
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = authService.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeController,
            builder: (context, mode, _) {
              return SwitchListTile(
                title: const Text('Dark mode'),
                value: mode == ThemeMode.dark,
                onChanged: themeController.setDark,
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Signed in as'),
            subtitle: Text(email ?? 'Unknown account'),
          ),
          ListTile(
            title: Text(
              'Sign out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }
}
