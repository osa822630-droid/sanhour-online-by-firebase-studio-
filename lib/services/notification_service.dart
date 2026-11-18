// lib/services/notification_service.dart
// ✅ P0-4 Fix: توجيه إرسال إشعارات الدفع (FCM Queue) عبر Cloud Function (enqueueNotification) بدلاً من الكتابة المباشرة
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _isDisposed = false;

  // ════════════════════════════════════════════════════════════════════════
  // 1. تهيئة الخدمة
  // ════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) =>
          _handleNotificationTap(response.payload),
    );

    await _createNotificationChannels();
    _requestPermissions();

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) _showFCMNotification(message);
    });

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleFCMData(message.data);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleFCMData(initial.data);

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? targetUid = prefs.getString('user_id');
        if (targetUid == null || targetUid.isEmpty) {
          final rawUser = prefs.getString('user_data');
          if (rawUser != null && rawUser.isNotEmpty) {
            final decoded = jsonDecode(rawUser);
            if (decoded is Map) {
              targetUid = decoded['id'] as String?;
            }
          }
        }
        final currentUser = FirebaseAuth.instance.currentUser;
        if ((targetUid == null || targetUid.isEmpty) &&
            currentUser != null &&
            !currentUser.isAnonymous) {
          targetUid = currentUser.uid;
        }
        if (targetUid != null &&
            targetUid.isNotEmpty &&
            targetUid != 'guest') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(targetUid)
              .update({
            'fcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        developer.log('onTokenRefresh update error: $e',
            name: 'NotificationService');
      }
    });
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();
    final channels = [
      const AndroidNotificationChannel(
          'merchant_stats', 'إحصائيات التاجر',
          description: 'تقارير دورية لأداء المتجر',
          importance: Importance.defaultImportance),
      const AndroidNotificationChannel(
          'merchant_subscription', 'الاشتراكات',
          description: 'تذكيرات تجديد الاشتراك',
          importance: Importance.high),
      const AndroidNotificationChannel(
          'merchant_reviews', 'تقييمات المتجر',
          description: 'إشعارات التقييمات الجديدة',
          importance: Importance.defaultImportance),
      const AndroidNotificationChannel(
          'user_favorites', 'تحديثات المفضلة',
          description: 'إشعارات محلاتك وعروضك المفضلة',
          importance: Importance.high),
      const AndroidNotificationChannel(
          'user_price_drops', 'انخفاض الأسعار',
          description: 'إشعارات تغيير الأسعار',
          importance: Importance.high),
      const AndroidNotificationChannel(
          'user_collections', 'قوائم المشتريات',
          description: 'تحديثات القوائم المشتركة',
          importance: Importance.defaultImportance),
      const AndroidNotificationChannel(
          'new_ads', 'إعلانات جديدة',
          description: 'أحدث العروض والإعلانات',
          importance: Importance.defaultImportance),
      const AndroidNotificationChannel(
          'user_support', 'الدعم الفني',
          description: 'ردود فريق الدعم',
          importance: Importance.high),
      const AndroidNotificationChannel(
          'admin_alerts', 'تنبيهات الإدارة',
          description: 'تنبيهات لوحة الإدارة',
          importance: Importance.high),
    ];

    for (final ch in channels) {
      await androidPlugin.createNotificationChannel(ch);
    }
  }

  void cleanup() {
    if (_isDisposed) return;
    _isDisposed = true;
    _foregroundSub?.cancel();
    _openedSub?.cancel();
  }

  // ════════════════════════════════════════════════════════════════════════
  // 2. Topics — الاشتراك حسب دور المستخدم
  // ════════════════════════════════════════════════════════════════════════

  static Future<void> subscribeToUserTopics(String userType) async {
    await FirebaseMessaging.instance.subscribeToTopic('all');
    switch (userType) {
      case 'admin':
      case 'super_admin':
      case 'moderator':
        await FirebaseMessaging.instance.subscribeToTopic('admins');
        break;
      case 'merchant':
        await FirebaseMessaging.instance.subscribeToTopic('merchants');
        break;
      default:
        await FirebaseMessaging.instance.subscribeToTopic('customers');
    }
  }

  static Future<void> unsubscribeFromAllTopics() async {
    for (final t in ['all', 'admins', 'merchants', 'customers']) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(t);
    }
  }

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 3. عرض FCM notifications
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _showFCMNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final channelId = message.data['channel'] as String? ?? 'new_ads';

    await _showNotification(
      id: message.hashCode,
      title: n.title ?? 'سنهور أونلاين',
      body: n.body ?? '',
      channelId: channelId,
      channelName: _channelLabel(channelId),
      payload: message.data['route']?.toString(),
    );
  }

  String _channelLabel(String id) {
    const map = {
      'merchant_stats': 'إحصائيات التاجر',
      'merchant_subscription': 'الاشتراكات',
      'merchant_reviews': 'تقييمات المتجر',
      'user_favorites': 'تحديثات المفضلة',
      'user_price_drops': 'انخفاض الأسعار',
      'user_collections': 'قوائم المشتريات',
      'new_ads': 'إعلانات جديدة',
      'user_support': 'الدعم الفني',
      'admin_alerts': 'تنبيهات الإدارة',
    };
    return map[id] ?? 'عام';
  }

  // ════════════════════════════════════════════════════════════════════════
  // 4. التوجيه الذكي
  // ════════════════════════════════════════════════════════════════════════

  void _handleFCMData(Map<String, dynamic> data) {
    final rawRoute = data['route']?.toString();
    if (rawRoute == null || rawRoute.isEmpty) return;
    final targetId =
        (data['targetId'] ?? data['shopId'] ?? data['requestId'])?.toString();
    final combined = (!rawRoute.contains(':') &&
            targetId != null &&
            targetId.isNotEmpty)
        ? '$rawRoute:$targetId'
        : rawRoute;
    _handleNotificationTap(combined);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split(':');
    final route = parts[0].trim();
    final id = parts.length > 1 ? parts.sublist(1).join(':').trim() : null;

    Future.delayed(const Duration(milliseconds: 300), () {
      final nav = navigatorKey.currentState;
      if (nav == null) return;

      switch (route) {
        case 'shop_details':
        case 'shop_detail':
          if (id != null && id.isNotEmpty) {
            nav.pushNamed('/shop_detail', arguments: {'shopId': id});
          } else {
            nav.pushNamed('/home');
          }
          break;

        case 'product_details':
        case 'product_detail':
          if (id != null && id.isNotEmpty) {
            nav.pushNamed('/product_detail', arguments: {'productId': id});
          } else {
            nav.pushNamed('/home');
          }
          break;

        case 'offer_details':
        case 'offer_detail':
          if (id != null && id.isNotEmpty) {
            nav.pushNamed('/offer_detail', arguments: {'offerId': id});
          } else {
            nav.pushNamed('/offers');
          }
          break;

        case 'ad_details':
        case 'all_ads':
          nav.pushNamed('/ads_hub', arguments: {'tab': 0});
          break;

        case 'job_ads':
          nav.pushNamed('/ads_hub', arguments: {'tab': 1});
          break;

        case 'service_requests':
        case 'service_request':
        case 'new_bid':
        case 'bid_accepted':
          nav.pushNamed('/ads_hub',
              arguments: {'tab': 2, if (id != null) 'requestId': id});
          break;

        case 'merchant':
          nav.pushNamed('/merchant');
          break;

        case 'collection':
          if (id != null && id.isNotEmpty) {
            nav.pushNamed('/collection_detail', arguments: {'collectionId': id});
          } else {
            nav.pushNamed('/favorites');
          }
          break;

        case 'favorites':
          nav.pushNamed('/favorites');
          break;

        case 'offers':
          nav.pushNamed('/offers');
          break;

        case 'notifications':
          nav.pushNamed('/notifications');
          break;

        case 'merchant_stats':
          nav.pushNamed('/merchant_stats');
          break;

        case 'merchant_reviews':
          nav.pushNamed('/merchant');
          break;

        case 'subscription':
          nav.pushNamed('/subscription',
              arguments: (id?.isNotEmpty == true) ? {'shopId': id} : null);
          break;

        case 'admin_complaints':
          nav.pushNamed('/admin');
          break;

        case 'user_complaints':
        case 'my_complaints':
          nav.pushNamed('/my_complaints');
          break;

        default:
          nav.pushNamed('/home');
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // 5. إشعارات المستخدم (Client-side)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> showFavoriteShopUpdate({
    required String shopName,
    required String itemTitle,
    required String itemId,
    required String itemType,
  }) async {
    String emoji, routePrefix;
    switch (itemType) {
      case 'offer':
        emoji = '🔥';
        routePrefix = 'offer_details';
        break;
      case 'service':
        emoji = '🔧';
        routePrefix = 'shop_details';
        break;
      default:
        emoji = '🛍️';
        routePrefix = 'product_details';
    }

    await _showNotification(
      id: '$shopName$itemId'.hashCode,
      title: '$emoji جديد في $shopName',
      body: '"$itemTitle" — الحق شوفه!',
      channelId: 'user_favorites',
      channelName: 'تحديثات المفضلة',
      payload: '$routePrefix:$itemId',
    );
  }

  Future<void> showPriceDropNotification({
    required String itemName,
    required String itemId,
    required double oldPrice,
    required double newPrice,
    String itemType = 'product',
  }) async {
    if (oldPrice <= 0) return;
    final diff = ((oldPrice - newPrice) / oldPrice * 100).round();
    final routePrefix =
        itemType == 'offer' ? 'offer_details' : 'product_details';

    await _showNotification(
      id: '$itemId price'.hashCode,
      title: 'السعر نزل $diff%! 📉',
      body:
          '"$itemName" نزل من ${oldPrice.toStringAsFixed(0)} لـ ${newPrice.toStringAsFixed(0)} جنيه!',
      channelId: 'user_price_drops',
      channelName: 'انخفاض الأسعار',
      payload: '$routePrefix:$itemId',
    );
  }

  Future<void> showCollectionUpdate({
    required String collectionName,
    required String collectionId,
    required String addedByName,
    required String itemName,
  }) async {
    await _showNotification(
      id: '$collectionId update'.hashCode,
      title: '🛒 تحديث في قائمة "$collectionName"',
      body: '$addedByName أضاف "$itemName" للقائمة',
      channelId: 'user_collections',
      channelName: 'قوائم المشتريات',
      payload: 'collection:$collectionId',
    );
  }

  Future<void> showNewAdNotification({
    required String adText,
    required String adId,
  }) async {
    final title = adText.isNotEmpty ? adText : 'إعلان جديد!';
    await _showNotification(
      id: adId.hashCode,
      title: '📢 ${title.length > 40 ? '${title.substring(0, 40)}...' : title}',
      body: 'اضغط لرؤية التفاصيل',
      channelId: 'new_ads',
      channelName: 'إعلانات جديدة',
      payload: 'ad_details:$adId',
    );

    await _writeToNotificationQueue(
      title: '📢 إعلان جديد في سنهور أونلاين',
      body: title.length > 60 ? '${title.substring(0, 60)}...' : title,
      topic: 'all',
      route: 'ad_details:$adId',
      channel: 'new_ads',
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 6. إشعارات التاجر المجدولة
  // ════════════════════════════════════════════════════════════════════════

  Future<void> scheduleDailyStats({required String shopName}) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 22);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _scheduleRecurringNotification(
      id: 200,
      title: '📊 إحصائيات $shopName — اليوم',
      body: 'اطّلع على أداء متجرك اليومي',
      channelId: 'merchant_stats',
      channelName: 'إحصائيات التاجر',
      scheduledDate: scheduled,
      payload: 'merchant_stats',
      matchComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWeeklyStats({required String shopName}) async {
    await _scheduleRecurringNotification(
      id: 201,
      title: '📈 حصاد الأسبوع — $shopName',
      body: 'تقرير الأسبوع جاهز! تفضل واطّلع على نتائجك',
      channelId: 'merchant_stats',
      channelName: 'إحصائيات التاجر',
      scheduledDate: _nextDayTime(DateTime.friday, 22, 0),
      payload: 'merchant_stats',
      matchComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> scheduleMonthlyStats({required String shopName}) async {
    final now = tz.TZDateTime.now(tz.local);
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, lastDay, 22);
    if (scheduled.isBefore(now)) {
      final next = DateTime(now.year, now.month + 1, 0);
      scheduled = tz.TZDateTime(tz.local, next.year, next.month, next.day, 22);
    }

    await _scheduleRecurringNotification(
      id: 202,
      title: '📋 تقرير شهر $shopName',
      body: 'شهر جديد بدأ! راجع إحصائياتك الشهرية',
      channelId: 'merchant_stats',
      channelName: 'إحصائيات التاجر',
      scheduledDate: scheduled,
      payload: 'merchant_stats',
      matchComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 7. تذكيرات تجديد الاشتراك
  // ════════════════════════════════════════════════════════════════════════

  Future<void> scheduleSubscriptionReminders({
    required DateTime expiryDate,
    required String shopId,
    required String shopName,
  }) async {
    final reminders = [
      {'days': 14, 'id': 300},
      {'days': 7, 'id': 301},
      {'days': 3, 'id': 302},
    ];

    for (final r in reminders) {
      final days = r['days'] as int;
      final id = r['id'] as int;
      final reminderDate = expiryDate.subtract(Duration(days: days));
      if (reminderDate.isBefore(DateTime.now())) continue;

      final tzDate = tz.TZDateTime.from(reminderDate, tz.local);
      await _scheduleNotification(
        id: id,
        title: '⏰ اشتراك $shopName ينتهي خلال $days يوم',
        body: 'جدّد اشتراكك الآن للحفاظ على ظهور متجرك',
        channelId: 'merchant_subscription',
        channelName: 'الاشتراكات',
        scheduledDate: tzDate,
        payload: 'subscription:$shopId',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 8. دوال الدعم الفني والإدارة
  // ════════════════════════════════════════════════════════════════════════

  Future<void> showNewReviewNotification(
      String shopName, double rating) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'تقييم جديد لمحلك 🌟',
      body: 'حصل $shopName على تقييم ${rating.toStringAsFixed(1)} نجوم.',
      channelId: 'merchant_reviews',
      channelName: 'تقييمات المتجر',
      payload: 'merchant_reviews',
    );
  }

  Future<void> showAdminReplyNotification(String ticketId) async {
    await _showNotification(
      id: ticketId.hashCode,
      title: 'رد جديد من الدعم 💬',
      body: 'فريق الدعم رد على رسالتك.',
      channelId: 'user_support',
      channelName: 'الدعم الفني',
      payload: 'user_complaints',
    );
  }

  Future<void> showNewComplaintNotification(String userName) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'شكوى/اقتراح جديد 📩',
      body: 'وصلتك رسالة جديدة من $userName.',
      channelId: 'admin_alerts',
      channelName: 'تنبيهات الإدارة',
      payload: 'admin_alerts',
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 9. إرسال إشعارات الدفع عبر Cloud Function (enqueueNotification — P0-4 Fixed)
  // ════════════════════════════════════════════════════════════════════════

  static Future<void> enqueuePushNotification({
    required String title,
    required String body,
    String? topic,
    String? targetUserId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('enqueueNotification');
      await callable.call({
        'title': title,
        'body': body,
        if (topic != null) 'topic': topic,
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (data != null) 'data': data,
      });
    } catch (e) {
      debugPrint('enqueuePushNotification error (non-critical): $e');
    }
  }

  static Future<void> _writeToNotificationQueue({
    required String title,
    required String body,
    required String topic,
    required String route,
    String channel = 'new_ads',
    String? targetUserId,
  }) async {
    await enqueuePushNotification(
      title: title,
      body: body,
      topic: targetUserId != null ? null : topic,
      targetUserId: targetUserId,
      data: {'route': route, 'channel': channel},
    );
  }

  static Future<void> triggerNewAdNotification({
    required String adId,
    required String adText,
  }) async {
    final title = adText.isNotEmpty ? adText : 'إعلان جديد!';
    await _writeToNotificationQueue(
      title: '📢 إعلان جديد في سنهور أونلاين',
      body: title.length > 80 ? '${title.substring(0, 80)}...' : title,
      topic: 'all',
      route: 'ad_details:$adId',
      channel: 'new_ads',
    );
  }

  static Future<void> triggerFavoriteShopUpdate({
    required String shopId,
    required String shopName,
    required String itemId,
    required String itemTitle,
    required String itemType,
  }) async {
    String emoji, route;
    switch (itemType) {
      case 'offer':
        emoji = '🔥';
        route = 'offer_details:$itemId';
        break;
      case 'service':
        emoji = '🔧';
        route = 'shop_details:$shopId';
        break;
      default:
        emoji = '🛍️';
        route = 'product_details:$itemId';
    }

    await _writeToNotificationQueue(
      title: '$emoji جديد في $shopName',
      body: '"$itemTitle" — الحق شوفه!',
      topic: 'shop_favorites_$shopId',
      route: route,
      channel: 'user_favorites',
    );
  }

  static Future<void> triggerPriceDrop({
    required String itemId,
    required String itemName,
    required double oldPrice,
    required double newPrice,
    required String itemType,
  }) async {
    if (oldPrice <= 0) return;
    final diff = ((oldPrice - newPrice) / oldPrice * 100).round();
    final route =
        itemType == 'offer' ? 'offer_details:$itemId' : 'product_details:$itemId';

    await _writeToNotificationQueue(
      title: 'السعر نزل $diff%! 📉',
      body:
          '"$itemName" من ${oldPrice.toStringAsFixed(0)} لـ ${newPrice.toStringAsFixed(0)} جنيه',
      topic: 'item_favorites_$itemId',
      route: route,
      channel: 'user_price_drops',
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 10. Low-level helpers
  // ════════════════════════════════════════════════════════════════════════

  void _requestPermissions() {
    _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelName,
            importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> _scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required tz.TZDateTime scheduledDate,
    required DateTimeComponents matchComponents,
    String? payload,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
      payload: payload,
    );
  }

  tz.TZDateTime _nextDayTime(int weekday, int hour, int minute) {
    var now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() async => await _notifications.cancelAll();
}
