// lib/utils/app_theme.dart
// ✅ هوية «الأوكالبتوس الهادئ والرملي الدافئ» (Calm Eucalyptus & Warm Sand)
// معايرة منفصلة للوضع الفاتح والوضع الليلي وفق OKLCH و WCAG 2.2 AA/AAA
import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppColors {
  AppColors._();

  // ── Core Brand Palette (Light Mode) ─────────────────────────────────────
  static const primary        = Color(0xFF3D6B5E); // أوكالبتوس مطفي هادئ
  static const primaryLight   = Color(0xFF73A899); // أوكالبتوس ناعم (أساسي في الليلي)
  static const primaryDark    = Color(0xFF26483F); // أوكالبتوس عميق

  // ── Secondary & Accent (10% CTA / Badges) ──────────────────────────────
  static const accent         = Color(0xFF4B5E6F); // رمادي بحري متزن
  static const accentDarkMode = Color(0xFF8CA3B8); // رمادي بحري ناعم في الليلي
  static const gold           = Color(0xFFC28542); // عسلي رملي دافئ (فاتح)
  static const goldDarkMode   = Color(0xFFE0A865); // عسلي رملي ناعم (ليلي)

  // ── Semantic Status (تُستخدم فقط للحالات الدلالية الصغيرة) ──────────────
  static const success        = Color(0xFF2E7D5B);
  static const error          = Color(0xFFC53B3B);
  static const warning        = Color(0xFFC28542);
  static const info           = Color(0xFF4B5E6F);

  // ── Neutral Surfaces (Light & Dark — zero harsh black, zero neon) ──────
  static const surface        = Color(0xFFF7F7F5); // خلفية دافئة ناعمة
  static const cardLight      = Color(0xFFFFFFFF);
  static const borderLight    = Color(0xFFE4E5E2);
  static const textPrimaryLt  = Color(0xFF1A1D21);
  static const textMutedLt    = Color(0xFF6B7280);

  static const surfaceDark    = Color(0xFF121514); // فحمي أوكالبتوسي ناعم
  static const cardDark       = Color(0xFF1B201E);
  static const inputDark      = Color(0xFF232927);
  static const borderDark     = Color(0xFF2B3330);
  static const textPrimaryDk  = Color(0xFFE6E8EB);
  static const textMutedDk    = Color(0xFF8E95A0);
  static const textMuted      = Color(0xFF6B7280);

  // ── Category Semantic Accents (هادئة ومتناسقة مع الباليت) ───────────────
  static const shopColor      = Color(0xFF3D6B5E);
  static const serviceColor   = Color(0xFF4B5E6F);
  static const offerColor     = Color(0xFFC28542);
  static const jobColor       = Color(0xFF3B6E8C);
  static const dealerColor    = Color(0xFF6D5A47);

  /// مساعد سريع لاختيار اللون الأساسي المعاير حسب الوضع الحالي
  static Color primaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? primaryLight : primary;

  static Color accentOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? goldDarkMode : gold;

  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardDark : cardLight;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : surface;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE2EFEA),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE6ECF1),
      onSecondaryContainer: Color(0xFF263340),
      tertiary: AppColors.gold,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF7ECE0),
      onTertiaryContainer: Color(0xFF5A3914),
      surface: AppColors.cardLight,
      onSurface: AppColors.textPrimaryLt,
      surfaceContainerLowest: AppColors.surface,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.borderLight,
      error: AppColors.error,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: AppColors.surface,
      cardColor: AppColors.cardLight,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Tajawal',
        bodyColor: AppColors.textPrimaryLt,
        displayColor: AppColors.textPrimaryLt,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Tajawal'),
      // ✅ شريط علوي نظيف ومحايد (أبيض ناعم مع حد سفلي رقيق 1px — أسلوب 2026 الهادئ)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardLight,
        foregroundColor: AppColors.textPrimaryLt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLt, size: AppIconSize.lg),
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLt,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.borderLight, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        prefixIconColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.textMutedLt),
        hintStyle: const TextStyle(color: AppColors.textMutedLt, fontSize: 13),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      dividerTheme: const DividerThemeData(
          color: AppColors.borderLight, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimaryLt,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
      ),
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: Color(0xFF0E1C18),
      primaryContainer: Color(0xFF203831),
      onPrimaryContainer: Color(0xFFCDE6DE),
      secondary: AppColors.accentDarkMode,
      onSecondary: Color(0xFF141D26),
      secondaryContainer: Color(0xFF24303B),
      onSecondaryContainer: Color(0xFFD5E1EC),
      tertiary: AppColors.goldDarkMode,
      onTertiary: Color(0xFF241707),
      tertiaryContainer: Color(0xFF382A18),
      onTertiaryContainer: Color(0xFFF5DEC0),
      surface: AppColors.cardDark,
      onSurface: AppColors.textPrimaryDk,
      surfaceContainerLowest: AppColors.surfaceDark,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderDark,
      error: Color(0xFFE57373),
      onError: Color(0xFF2B0B0B),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: AppColors.surfaceDark,
      cardColor: AppColors.cardDark,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Tajawal',
        bodyColor: AppColors.textPrimaryDk,
        displayColor: AppColors.textPrimaryDk,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Tajawal'),
      // ✅ شريط علوي ليلي محايد وهادئ (فحمي أوكالبتوسي ناعم بدون إجهاد عين)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.textPrimaryDk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDk, size: AppIconSize.lg),
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDk,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: const Color(0xFF0E1C18),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.borderDark, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.6),
        ),
        prefixIconColor: AppColors.primaryLight,
        labelStyle: const TextStyle(color: AppColors.textMutedDk),
        hintStyle: const TextStyle(color: AppColors.textMutedDk, fontSize: 13),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.inputDark,
        selectedColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.borderDark),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primaryLight),
      dividerTheme: const DividerThemeData(
          color: AppColors.borderDark, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF262D2A),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
      ),
    );
  }
}
