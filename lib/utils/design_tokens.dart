// lib/utils/design_tokens.dart
// ✅ نظام التوكنز الموحّد لتطبيق سنهور أونلاين (Calm Eucalyptus & Warm Sand)
// يفرض شبكة مسافات 4dp، و4 درجات حواف، و4 مقاسات أيقونات، ومنحنيات حركة قياسية.
import 'package:material_ui/material_ui.dart';

/// شبكة المسافات القياسية (مضاعفات 4dp)
class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// 4 درجات انحناء قياسية فقط في كامل التطبيق
class AppRadius {
  AppRadius._();
  static const double sm = 8.0;    // شارات وأزرار صغيرة
  static const double md = 12.0;   // حقول إدخال وأزرار أساسية
  static const double lg = 16.0;   // بطاقات المحلات والمنتجات
  static const double xl = 24.0;   // BottomSheets و Dialogs
  static const double pill = 999.0;

  static final BorderRadius cardRadius = BorderRadius.circular(lg);
  static final BorderRadius buttonRadius = BorderRadius.circular(md);
  static final BorderRadius inputRadius = BorderRadius.circular(md);
  static final BorderRadius chipRadius = BorderRadius.circular(pill);
}

/// 4 مقاسات أيقونات قياسية فقط
class AppIconSize {
  AppIconSize._();
  static const double sm = 16.0;     // داخل الشارات والبطاقات المدمجة
  static const double md = 20.0;     // أيقونات مساندة
  static const double lg = 24.0;     // أيقونات الشريط العلوي والسفلي والأزرار
  static const double empty = 52.0;  // حالات الفراغ والأخطاء
}

/// توكنز الحركة (وفق قواعد Emil Kowalski و Material 3 Expressive)
class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 300);
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}
