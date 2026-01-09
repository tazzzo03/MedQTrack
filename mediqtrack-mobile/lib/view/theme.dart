import 'package:flutter/material.dart';

ThemeData buildMediTheme() {
  const primaryBlue = Color(0xFF1565C0);
  const bgLight = Color(0xFFE3F2FD);
  const teal = Color(0xFF00BFA5);

  final scheme = ColorScheme.fromSeed(
    seedColor: primaryBlue,
    primary: primaryBlue,
    secondary: teal,
    surface: Colors.white,
    background: bgLight,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.primary,
      elevation: 0,
      titleTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
    ),
  );
}
