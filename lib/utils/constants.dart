// lib_utils_constants.dart
import 'package:flutter/material.dart';

// =========================================================
// 1. ثوابت التطبيق الرئيسية (App Info & Colors)
// =========================================================
class AppConstants {
  // ✅ منع إنشاء نسخة من الكلاس (Optimization)
  AppConstants._();

  // معلومات التطبيق
  static const String appName = 'سنهور أونلاين';
  static const String appDescription = 'سنهور كلها في جيبك';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // الألوان الأساسية
  static const Color primaryColor = Color(0xFF5E35B1);
  static const Color secondaryColor = Color(0xFF7B1FA2);
  static const Color accentColor = Color(0xFFAB47BC);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color infoColor = Color(0xFF1976D2);

  // ألوان النص
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // ألوان الخلفية
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color dialogBackground = Color(0xFFFFFFFF);

  // ألوان الحالات
  static const Color activeColor = Color(0xFF7E57C2);
  static const Color inactiveColor = Color(0xFF9E9E9E);
  static const Color pendingColor = Color(0xFFFF9800);
  static const Color rejectedColor = Color(0xFFF44336);

  // الروابط والشبكات
  static const String baseUrl = 'https://api.sanhour.com';
  static const String imageBaseUrl = 'https://images.sanhour.com';
  static const String termsUrl = 'https://sanhour.com/terms';
  static const String privacyUrl = 'https://sanhour.com/privacy';
  static const String supportEmail = 'support@sanhour.com';
  static const String supportPhone = '+20123456789';


  // ✅ Gemini AI
  // ✅ Fix #127: لا placeholder ثابت في الكود — المفتاح يُحمَّل من Firestore فقط (settings/general.geminiApiKey)
  // GeminiService.setApiKey() تُستدعى من AuthProvider بعد تسجيل الدخول
  static const String geminiApiKey = ''; // فارغ عمداً — لا تضع API key هنا أبداً
  static const String geminiModel = 'gemini-1.5-flash';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  // إعدادات التطبيق
  static const int itemsPerPage = 20;
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxExcelFileSize = 10 * 1024 * 1024; // 10MB
  static const int cacheDurationHours = 1;
  static const int searchDebounceMs = 500;
  static const int autoSaveDelayMs = 2000;
  static const int passwordMinLength = 6;
  static const int otpTimeoutSeconds = 300;

  // أنواع المستخدمين
  static const String userTypeCustomer = 'customer';
  static const String userTypeMerchant = 'merchant';
  static const String userTypeAdmin = 'admin';
  static const String userTypeGuest = 'guest';

  // حالات العناصر
  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // أنواع المحتوى
  static const String contentTypeShop = 'shop';
  static const String contentTypeProduct = 'product';
  static const String contentTypeOffer = 'offer';
  static const String contentTypeCategory = 'category';

  // إعدادات الوقت
  static const int notificationCheckInterval = 300; // 5 دقائق
  static const int autoRefreshInterval = 60000; // 1 دقيقة
  static const int sessionTimeout = 3600000; // 1 ساعة

  // المفاتيح المحلية (Shared Preferences Keys)
  static const String keyAuthToken = 'auth_token';
  static const String keyUserData = 'user_data';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyNotifications = 'notifications_enabled';
  static const String keyLocation = 'location_enabled';

  // الصيغ المسموحة
  static const List<String> allowedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp'
  ];
  static const List<String> allowedDocumentFormats = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx'
  ];
  static const List<double> allowedRatings = [
    1.0,
    1.5,
    2.0,
    2.5,
    3.0,
    3.5,
    4.0,
    4.5,
    5.0
  ];

  // القيم الافتراضية
  static const double defaultRating = 4.0;
  static const int defaultViews = 0;
  static const int defaultFavorites = 0;
  static const int defaultReviews = 0;
  static const bool defaultIsFeatured = false;
  static const bool defaultIsActive = true;
  static const bool defaultIsFavorite = false;

  // النصوص الثابتة
  static const String noInternetMessage = 'لا يوجد اتصال بالإنترنت';
  static const String serverErrorMessage = 'حدث خطأ في الخادم';
  static const String unknownErrorMessage = 'حدث خطأ غير متوقع';
  static const String loadingMessage = 'جاري التحميل...';
  static const String noDataMessage = 'لا توجد بيانات';
  static const String searchHint = 'ابحث عن محلات، منتجات، عروض...';
  static const String retryButton = 'إعادة المحاولة';
  static const String cancelButton = 'إلغاء';
  static const String confirmButton = 'تأكيد';
  static const String saveButton = 'حفظ';
  static const String deleteButton = 'حذف';
  static const String editButton = 'تعديل';
  static const String viewButton = 'عرض';
}

// =========================================================
// 2. ثوابت التصميم (UI Metrics)
// =========================================================
class DesignConstants {
  DesignConstants._();

  // المسافات والحواف
  static const double paddingExtraSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingExtraLarge = 32.0;

  // أنصاف الأقطار
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusExtraLarge = 24.0;

  // أحجام العناصر
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeExtraLarge = 48.0;

  // ارتفاعات العناصر
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 48.0;
  static const double buttonHeightLarge = 56.0;
  static const double appBarHeight = 56.0;
  static const double bottomBarHeight = 64.0;
  static const double inputFieldHeight = 56.0;

  // عروض العناصر
  static const double buttonMinWidth = 88.0;
  static const double dialogWidth = 400.0;
  static const double sideMenuWidth = 280.0;
  static const double productImageSize = 120.0;
  static const double shopImageSize = 80.0;

  // الظلال
  static const BoxShadow cardShadowSmall = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 4.0,
    offset: Offset(0, 2),
  );

  static const BoxShadow cardShadowMedium = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 8.0,
    offset: Offset(0, 4),
  );

  static const BoxShadow cardShadowLarge = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 16.0,
    offset: Offset(0, 8),
  );

  // مدة الحركات
  static const Duration animationDurationShort = Duration(milliseconds: 200);
  static const Duration animationDurationMedium = Duration(milliseconds: 300);
  static const Duration animationDurationLong = Duration(milliseconds: 500);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);

  // منحنيات الحركات
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve elasticCurve = Curves.elasticOut;
}

// =========================================================
// 3. ثوابت المحتوى والفئات (Content Data)
// =========================================================
class ContentConstants {
  ContentConstants._();

  // أيام الأسبوع
  static const Map<int, String> weekDays = {
    1: 'السبت',
    2: 'الأحد',
    3: 'الاثنين',
    4: 'الثلاثاء',
    5: 'الأربعاء',
    6: 'الخميس',
    7: 'الجمعة',
  };

  // أشهر السنة
  static const Map<int, String> months = {
    1: 'يناير',
    2: 'فبراير',
    3: 'مارس',
    4: 'أبريل',
    5: 'مايو',
    6: 'يونيو',
    7: 'يوليو',
    8: 'أغسطس',
    9: 'سبتمبر',
    10: 'أكتوبر',
    11: 'نوفمبر',
    12: 'ديسمبر',
  };
}

// =========================================================
// 4. ثوابت الشبكة (API Endpoints)
// =========================================================
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.sanhour.com';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/profile';

  static const String shops = '/shops';
  static const String shopsFeatured = '/shops/featured';
  static const String shopsTop = '/shops/top';

  static const String products = '/products';
  static const String productsByShop = '/products/shop';
  static const String productsTop = '/products/top';

  static const String offers = '/offers';
  static const String offersActive = '/offers/active';
  static const String offersExpiring = '/offers/expiring';

  static const String favorites = '/favorites';
  static const String reviews = '/reviews';
  static const String ratings = '/ratings';

  static const String analytics = '/analytics';
  static const String stats = '/stats';
  static const String dashboard = '/dashboard';

  static const String upload = '/upload';
  static const String excel = '/excel';

  static const String notifications = '/notifications';
  static const String settings = '/settings';
}

// =========================================================
// 5. ثوابت الإشعارات (Notifications)
// =========================================================
class NotificationConstants {
  NotificationConstants._();

  static const String channelGeneral = 'general_channel';
  static const String channelOffers = 'offers_channel';
  static const String channelOrders = 'orders_channel';
  static const String channelSystem = 'system_channel';

  static const Map<String, String> channels = {
    channelGeneral: 'إشعارات عامة',
    channelOffers: 'عروض وتخفيضات',
    channelOrders: 'تحديثات الطلبات',
    channelSystem: 'إشعارات النظام',
  };

  static const int dailyNotificationId = 1001;
  static const int weeklyNotificationId = 1002;
  static const int monthlyNotificationId = 1003;
}

// =========================================================
// 6. ثوابت التخزين (Local Storage)
// =========================================================
class StorageConstants {
  StorageConstants._();

  static const String shopsBox = 'shops_cache';
  static const String productsBox = 'products_cache';
  static const String offersBox = 'offers_cache';
  static const String searchBox = 'search_cache';
  static const String userBox = 'user_cache';

  static const int cacheVersion = 1;
  static const Duration cacheDuration = Duration(hours: 1);
}

// =========================================================
// 7. ثوابت التحليلات (Analytics)
// =========================================================
class AnalyticsConstants {
  AnalyticsConstants._();

  static const String appOpen = 'app_open';
  static const String screenView = 'screen_view';
  static const String search = 'search';
  static const String viewItem = 'view_item';
  static const String addToFavorites = 'add_to_favorites';
  static const String removeFromFavorites = 'remove_from_favorites';
  static const String addReview = 'add_review';
  static const String share = 'share';
}
