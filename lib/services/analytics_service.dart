// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import '../models/offer.dart';
import '../models/product.dart';
import '../models/shop.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ✅ مراقب لـ Firebase Analytics (تسجيل كل شاشة تلقائياً)
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> init() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      debugPrint('Analytics init error: $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  Future<void> logSearch(String term) async {
    try {
      await _analytics.logSearch(searchTerm: term);
    } catch (_) {}
  }

  Future<void> logViewItem(dynamic item) async {
    try {
      if (item is Shop) {
        await _analytics.logViewItem(items: [
          AnalyticsEventItem(itemId: item.id, itemName: item.name, itemCategory: item.category),
        ]);
      } else if (item is Product) {
        await _analytics.logViewItem(items: [
          AnalyticsEventItem(itemId: item.id, itemName: item.name,
              itemCategory: item.category, price: item.price, affiliation: item.shopId),
        ]);
      } else if (item is Offer) {
        await _analytics.logViewItem(items: [
          AnalyticsEventItem(itemId: item.id, itemName: item.title,
              itemCategory: 'offer', affiliation: item.shopId),
        ]);
      }
    } catch (_) {}
  }

  Future<void> logAddToFavorites(String itemId, String itemType) async {
    try {
      await _analytics.logAddToWishlist(items: [
        AnalyticsEventItem(itemId: itemId, itemCategory: itemType),
      ]);
    } catch (_) {}
  }

  Future<void> logShareItem(String itemId, String contentType, String method) async {
    try {
      await _analytics.logShare(contentType: contentType, itemId: itemId, method: method);
    } catch (_) {}
  }

  Future<void> logUserRegistration(String userType) async {
    try {
      await _analytics.logSignUp(signUpMethod: 'phone');
      await _analytics.logEvent(name: 'user_registration', parameters: {'user_type': userType});
    } catch (_) {}
  }

  Future<void> logUserLogin(String userType) async {
    try {
      await _analytics.logLogin(loginMethod: 'phone');
      await _analytics.logEvent(name: 'user_login', parameters: {'user_type': userType});
    } catch (_) {}
  }

  Future<void> logContactClick(String shopId, String method) async {
    try {
      await _analytics.logEvent(name: 'contact_click', parameters: {
        'shop_id': shopId, 'method': method, // 'phone' or 'whatsapp'
      });
    } catch (_) {}
  }

  Future<void> logReviewSubmission(String itemType, double rating) async {
    try {
      await _analytics.logEvent(name: 'review_submission', parameters: {
        'item_type': itemType, 'rating': rating,
      });
    } catch (_) {}
  }

  // ✅ Fix #139: لا نُرسل بيانات شخصية (PII) — query يُقتطع ولا يُرسل كاملاً
  Future<void> logAdvancedSearch(String query, Map<String, dynamic> filters) async {
    try {
      // قطع الـ query عند 20 حرفاً لمنع تسريب نصوص حساسة
      final safeQuery = query.length > 20 ? '${query.substring(0, 20)}…' : query;
      await _analytics.logEvent(name: 'advanced_search', parameters: {
        'query_length': query.length,
        'query_prefix': safeQuery,
        ...filters,
      });
    } catch (_) {}
  }

  Future<void> setUserProperties({String? userType, String? userId}) async {
    try {
      if (userType != null) {
        await _analytics.setUserProperty(name: 'user_type', value: userType);
      }
      // ✅ Fix #139: لا نُرسل userId الفعلي — Firebase يتولى الربط داخلياً
      // استخدام setUserId فقط في بيئة Debug
      if (userId != null && kDebugMode) {
        await _analytics.setUserId(id: userId);
      }
    } catch (_) {}
  }

  Future<void> logErrorEvent(String errorType, String errorMessage) async {
    try {
      await _analytics.logEvent(name: 'app_error', parameters: {
        'error_type': errorType,
        'error_message': errorMessage.length > 100 ? errorMessage.substring(0, 100) : errorMessage,
      });
    } catch (_) {}
  }
}
