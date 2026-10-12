// lib/utils/app_theme.dart
// ✅ Pro #220: مركزة ألوان التطبيق في مكان واحد لسهولة التغيير
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const primary        = Color(0xFF5E35B1);
  static const primaryLight   = Color(0xFF9162E4);
  static const primaryDark    = Color(0xFF320B86);

  // Accent
  static const accent         = Color(0xFF3949AB);
  static const gold           = Color(0xFFFFC107);

  // Semantic
  static const success        = Color(0xFF4CAF50);
  static const error          = Color(0xFFF44336);
  static const warning        = Color(0xFFFF9800);
  static const info           = Color(0xFF2196F3);

  // Neutral
  static const surface        = Color(0xFFF8F7FF);
  static const surfaceDark    = Color(0xFF1A1A2E);
  static const textMuted      = Color(0xFF9E9E9E);

  // Category colors
  static const shopColor      = Color(0xFF5E35B1);
  static const serviceColor   = Color(0xFF00897B);
  static const offerColor     = Color(0xFFE53935);
  static const jobColor       = Color(0xFF1E88E5);
  static const dealerColor    = Color(0xFF6D4C41);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.light,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    // ✅ إصلاح API قديم: ThemeData.cardTheme يتوقع CardThemeData وليس
    // CardTheme (تطبيع أنواع الثيمات Component theme normalization)
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.dark,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.surfaceDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0E0E1A),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    // ✅ إصلاح API قديم: ThemeData.cardTheme يتوقع CardThemeData وليس CardTheme
    cardTheme: CardThemeData(
      elevation: 2,
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
