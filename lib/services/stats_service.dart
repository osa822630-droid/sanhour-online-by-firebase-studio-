// lib/services/stats_service.dart
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // 1. تسجيل الزيارات والتفاعل (Logging) - حقيقي
  // ==========================================================

  static Future<void> logShopVisit(String shopId) async {
    // ✅ QA Fix #19: FieldValue.increment بدلاً من Transaction لتجنب Firestore contention
    // FieldValue.increment ذري تلقائياً — لا حاجة لـ transaction
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      final shopRef = _firestore.collection('shops').doc(shopId);

      await Future.wait([
        shopRef.update({'views': FieldValue.increment(1)}),
        shopRef.collection('daily_stats').doc(dateKey).set({
          'views': FieldValue.increment(1),
          'date': Timestamp.fromDate(
              DateTime(today.year, today.month, today.day)),
        }, SetOptions(merge: true)),
      ]);
    } catch (e) {
      developer.log('logShopVisit error: \$e', name: 'StatsService');
    }
  }

  // ✅ Fix #53: تغليف بـ try/catch لمنع crash عند حذف المنتج/العرض
  static Future<void> logProductVisit(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      developer.log('logProductVisit error: $e', name: 'StatsService');
    }
  }

  static Future<void> logOfferVisit(String offerId) async {
    try {
      await _firestore.collection('offers').doc(offerId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      developer.log('logOfferVisit error: $e', name: 'StatsService');
    }
  }

  // ==========================================================
  // ✅ قسم 6: إحصائيات ضغط رقم الهاتف والواتساب
  // ==========================================================

  static Future<void> logPhoneClick(String shopId) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      final shopRef = _firestore.collection('shops').doc(shopId);

      // زيادة الإجمالي على المحل
      await shopRef.update({'phoneClicks': FieldValue.increment(1)});

      // تسجيل يومي تفصيلي
      await shopRef
          .collection('daily_stats')
          .doc(dateKey)
          .set({'phoneClicks': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      developer.log('logPhoneClick error: $e', name: 'StatsService');
    }
  }

  static Future<void> logWhatsAppClick(String shopId) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      final shopRef = _firestore.collection('shops').doc(shopId);

      await shopRef.update({'whatsappClicks': FieldValue.increment(1)});

      await shopRef
          .collection('daily_stats')
          .doc(dateKey)
          .set({'whatsappClicks': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      developer.log('logWhatsAppClick error: $e', name: 'StatsService');
    }
  }

  /// ✅ تسجيل ضغطة على رابط التواصل الاجتماعي (facebook/instagram/tiktok/telegram)
  static Future<void> logSocialClick(String shopId, String platform) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      final shopRef = _firestore.collection('shops').doc(shopId);
      final field = '${platform}Clicks';

      await shopRef.update({field: FieldValue.increment(1)});
      await shopRef
          .collection('daily_stats')
          .doc(dateKey)
          .set({field: FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      developer.log('logSocialClick error: $e', name: 'StatsService');
    }
  }

  // ==========================================================
  // 2. الإحصائيات المتقدمة للمتجر (Dashboard Data)
  // ==========================================================

  static Future<Map<String, dynamic>> getMerchantAdvancedStats(String shopId,
      {DateTime? start, DateTime? end}) async {
    try {
      final now = DateTime.now();
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) return {};
      final shopData = shopDoc.data()!;

      int currentViews = shopData['views'] ?? 0;
      String category = shopData['category'] ?? '';

      final globalRankQuery = await _firestore
          .collection('shops')
          .where('views', isGreaterThan: currentViews)
          .count()
          .get();
      int globalRank = (globalRankQuery.count ?? 0) + 1;

      final categoryRankQuery = await _firestore
          .collection('shops')
          .where('category', isEqualTo: category)
          .where('views', isGreaterThan: currentViews)
          .count()
          .get();
      int categoryRank = (categoryRankQuery.count ?? 0) + 1;

      final totalCompetitorsQuery = await _firestore
          .collection('shops')
          .where('category', isEqualTo: category)
          .count()
          .get();

      final historySnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('daily_stats')
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      Map<String, int> dailyViewsMap = {};
      for (var doc in historySnapshot.docs) {
        DateTime date = (doc['date'] as Timestamp).toDate();
        String key = '${date.year}-${date.month}-${date.day}';
        dailyViewsMap[key] = doc['views'] ?? 0;
      }

      String todayKey = '${now.year}-${now.month}-${now.day}';
      DateTime yesterday = now.subtract(const Duration(days: 1));
      String yesterdayKey =
          '${yesterday.year}-${yesterday.month}-${yesterday.day}';
      var dailyPerf = _calculateChange(
          dailyViewsMap[todayKey] ?? 0, dailyViewsMap[yesterdayKey] ?? 0);

      int thisWeekViews = 0;
      int lastWeekViews = 0;
      for (int i = 0; i < 7; i++) {
        DateTime d = now.subtract(Duration(days: i));
        thisWeekViews += dailyViewsMap['${d.year}-${d.month}-${d.day}'] ?? 0;
      }
      for (int i = 7; i < 14; i++) {
        DateTime d = now.subtract(Duration(days: i));
        lastWeekViews += dailyViewsMap['${d.year}-${d.month}-${d.day}'] ?? 0;
      }
      var weeklyPerf = _calculateChange(thisWeekViews, lastWeekViews);

      List<Map<String, dynamic>> chartData = [];
      for (int i = 6; i >= 0; i--) {
        DateTime d = now.subtract(Duration(days: i));
        String k = '${d.year}-${d.month}-${d.day}';
        chartData.add({
          'day': _getDayName(d.weekday),
          'value': dailyViewsMap[k] ?? 0,
        });
      }

      final productsCountQuery = await _firestore
          .collection('products')
          .where('shopId', isEqualTo: shopId)
          .count()
          .get();
      final offersCountQuery = await _firestore
          .collection('offers')
          .where('shopId', isEqualTo: shopId)
          .count()
          .get();

      return {
        'totalViews': currentViews,
        'totalFavorites': shopData['favoriteCount'] ?? 0,
        'avgRating': (shopData['rating'] ?? 0.0).toDouble(),
        'rank': categoryRank,
        'globalRank': globalRank,
        'totalCompetitors': totalCompetitorsQuery.count ?? 0,
        'productsCount': productsCountQuery.count ?? 0,
        'offersCount': offersCountQuery.count ?? 0,
        'weeklyViews': chartData,
        // ✅ قسم 6: إحصائيات التفاعل
        'phoneClicks': shopData['phoneClicks'] ?? 0,
        'whatsappClicks': shopData['whatsappClicks'] ?? 0,
        'facebookClicks': shopData['facebookClicks'] ?? 0,
        'instagramClicks': shopData['instagramClicks'] ?? 0,
        'tiktokClicks': shopData['tiktokClicks'] ?? 0,
        'telegramClicks': shopData['telegramClicks'] ?? 0,
        'performance': {
          'daily': dailyPerf,
          'weekly': weeklyPerf,
        },
      };
    } catch (e, s) {
      developer.log("Stats Logic Error: $e", name: 'StatsService', error: e, stackTrace: s);
      return {};
    }
  }

  // ==========================================================
  // 3. تحليل المنتجات/العروض (Top Items) - حقيقي
  // ==========================================================

  static Future<List<Map<String, dynamic>>> getTopItems({
    required String shopId,
    required String type,
    required String sortBy,
    int limit = 100,
  }) async {
    Query query =
        _firestore.collection(type).where('shopId', isEqualTo: shopId);

    if (sortBy == 'views') {
      query = query.orderBy('views', descending: true);
    } else if (sortBy == 'rating') {
      query = query.orderBy('rating', descending: true);
    } else if (sortBy == 'favorites') {
      query = query.orderBy('favoriteCount', descending: true);
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': type == 'products' ? data['name'] : data['title'],
        'views': data['views'] ?? 0,
        'rating': (data['rating'] ?? 0.0).toDouble(),
        'favoriteCount': data['favoriteCount'] ?? 0,
        'image': (data['imageUrl'] != null)
            ? data['imageUrl']
            : (data['imageUrls'] != null &&
                    (data['imageUrls'] as List).isNotEmpty
                ? data['imageUrls'][0]
                : ''),
      };
    }).toList();
  }

  // ==========================================================
  // 4. بادجات الترتيب (Ranking Badges) - ميزة جديدة 🔥
  // ==========================================================

  static Future<Map<String, int>> getItemRank({
    required String collection,
    required String id,
    required int currentViews,
    String? category,
  }) async {
    final globalCount = await _firestore
        .collection(collection)
        .where('views', isGreaterThan: currentViews)
        .count()
        .get();

    int globalRank = (globalCount.count ?? 0) + 1;
    int categoryRank = 0;

    if (category != null && category.isNotEmpty) {
      final categoryCount = await _firestore
          .collection(collection)
          .where('category', isEqualTo: category)
          .where('views', isGreaterThan: currentViews)
          .count()
          .get();
      categoryRank = (categoryCount.count ?? 0) + 1;
    }

    return {
      'global': globalRank,
      'category': categoryRank,
    };
  }

  // ==========================================================
  // 5. دوال مساعدة (Helpers)
  // ==========================================================

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      default:
        return '';
    }
  }

  static Map<String, dynamic> _calculateChange(int current, int previous) {
    if (previous == 0) {
      return {
        'value': current,
        'change': current == 0 ? 0.0 : 100.0,
        'isUp': true
      };
    }
    double change = ((current - previous) / previous) * 100;
    return {
      'value': current,
      'change': double.parse(change.toStringAsFixed(1)),
      'isUp': change >= 0,
    };
  }
}
