import 'package:flutter/material.dart';

/// Colors lifted from the app's original design mockup ("Receipt Ledger
/// Flow"), a paper-ledger palette: navy brand, warm off-white paper,
/// muted terracotta for errors/negative trends, sage for positive ones.
class AppTheme {
  AppTheme._();

  static const _onBrand = Color(0xFFF4F7FA);

  static const sageLight = Color(0xFF4F7D57);
  static const sageDark = Color(0xFF8ABE92);

  static ThemeData get light => _theme(
    brightness: Brightness.light,
    paper: const Color(0xFFF4F5F0),
    paperRaised: const Color(0xFFFFFFFF),
    paperSunken: const Color(0xFFECEDE6),
    ink: const Color(0xFF1E2A38),
    inkDim: const Color(0xFF5B6672),
    brand: const Color(0xFF24374D),
    // Buttons match the app bar's navy in light mode — it already stands
    // out clearly against the light paper background.
    primaryButton: const Color(0xFF24374D),
    onPrimaryButton: _onBrand,
    stamp: const Color(0xFFB23A2E),
    stampSoft: const Color(0xFFF5E3E0),
    line: const Color(0xFFDCDDD5),
  );

  static ThemeData get dark => _theme(
    brightness: Brightness.dark,
    paper: const Color(0xFF14181D),
    paperRaised: const Color(0xFF1C222A),
    paperSunken: const Color(0xFF10141A),
    ink: const Color(0xFFECEAE2),
    inkDim: const Color(0xFF9AA3AC),
    brand: const Color(0xFF202E3F),
    // The app bar keeps the dark navy brand, but buttons use a lighter
    // accent instead — the dark navy barely contrasts against the
    // near-black page background, so filled buttons would nearly
    // disappear if they matched the app bar exactly.
    primaryButton: const Color(0xFF8CB2E0),
    onPrimaryButton: const Color(0xFF14202E),
    stamp: const Color(0xFFE2786A),
    stampSoft: const Color(0xFF3A2523),
    line: const Color(0xFF2A3038),
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color paper,
    required Color paperRaised,
    required Color paperSunken,
    required Color ink,
    required Color inkDim,
    required Color brand,
    required Color primaryButton,
    required Color onPrimaryButton,
    required Color stamp,
    required Color stampSoft,
    required Color line,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(seedColor: brand, brightness: brightness).copyWith(
          primary: primaryButton,
          onPrimary: onPrimaryButton,
          secondary: primaryButton,
          error: stamp,
          onError: _onBrand,
          errorContainer: stampSoft,
          onErrorContainer: stamp,
          surface: paperRaised,
          onSurface: ink,
          surfaceContainerHighest: paperSunken,
          onSurfaceVariant: inkDim,
          outline: line,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      appBarTheme: AppBarTheme(
        backgroundColor: brand,
        foregroundColor: _onBrand,
      ),
      cardTheme: CardThemeData(
        color: paperRaised,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
