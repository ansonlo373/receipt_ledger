import 'package:flutter/material.dart';
import 'package:receipt_ledger/theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, mode, _) {
          return SwitchListTile(
            title: const Text('Dark mode'),
            value: mode == ThemeMode.dark,
            onChanged: themeController.setDark,
          );
        },
      ),
    );
  }
}
