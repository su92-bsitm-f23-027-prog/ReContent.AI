import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF20233B);
  static const muted = Color(0xFF777B91);
  static const canvas = Color(0xFFF6F7FB);
  static const violet = Color(0xFF6657D9);
  static const violetSoft = Color(0xFFEDEAFF);
  static const mint = Color(0xFF1D9A84);
  static const mintSoft = Color(0xFFE3F5EF);
  static const orange = Color(0xFFEA9457);
  static const border = Color(0xFFE9EAF1);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    primary: AppColors.violet,
    secondary: AppColors.mint,
    surface: AppColors.white,
    error: const Color(0xFFB83F51),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -.7,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -.4,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.45),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
      ),
    ),
  );
}
