// lib/services/subscription_service.dart
// ✅ P0-2 & P1-7 Fix: توجيه تجديد الاشتراك والتحقق من الأكواد عبر Cloud Functions (renewShopSubscription & checkActivationCode)
import 'dart:developer' as developer;
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/notification_service.dart';
import '../services/audit_log_service.dart';

class SubscriptionResult {
  final bool success;
  final String? error;
  final DateTime? newEndDate;

  const SubscriptionResult.ok(this.newEndDate)
      : success = true,
        error = null;

  const SubscriptionResult.fail(this.error)
      : success = false,
        newEndDate = null;
}

class SubscriptionService {
  SubscriptionService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;

  static const Map<String, Map<String, dynamic>> tiers = {
    'monthly': {
      'label': 'شهري',
      'price': 99,
      'days': 30,
    },
    'quarterly': {
      'label': 'ربع سنوي',
      'price': 249,
      'days': 90,
      'badge': 'وفر 16%',
    },
    'yearly': {
      'label': 'سنوي',
      'price': 799,
      'days': 365,
      'badge': 'الأوفر',
    },
  };

  static DateTime calculateNewExpiry(DateTime? currentEnd, int planDays) {
    final now = DateTime.now();
    final base =
        (currentEnd != null && currentEnd.isAfter(now)) ? currentEnd : now;
    return base.add(Duration(days: planDays));
  }

  // ── 1. جلب بيانات اشتراك المحل ──────────────────────────────────
  static Future<Map<String, dynamic>?> getSubscription(String shopId) async {
    try {
      final doc = await _db.collection('shops').doc(shopId).get();
      return doc.exists ? doc.data() : null;
    } catch (e, s) {
      developer.log('getSubscription error', error: e, stackTrace: s);
      return null;
    }
  }

  static const String renewalCodeType = 'shop_renewal';

  /// توليد كود تجديد اشتراك متجر (RNW-XXXX-XXXX) بواسطة الأدمن
  static Future<String> generateRenewalCode({
    String adminId = 'admin',
    String tier = 'monthly',
  }) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    String part() =>
        List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    final code = 'RNW-${part()}-${part()}';
    final tierSpec = tiers[tier] ?? tiers['monthly']!;

    await _db.collection('activation_codes').doc(code).set({
      'code': code,
      'type': renewalCodeType,
      'tier': tier,
      'days': tierSpec['days'],
      'price': tierSpec['price'],
      'isUsed': false,
      'generatedBy': adminId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
    });

    await AuditLogService.logActivationCodeGenerated(code,
        generatedBy: adminId);
    return code;
  }

  static Future<bool> isCodeValid(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    try {
      final callable = _functions.httpsCallable('checkActivationCode');
      final res = await callable.call({
        'code': normalized,
        'expectedType': renewalCodeType,
      });
      final data = res.data;
      return data is Map && data['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── 3. تجديد الاشتراك ذرياً على الخادم عبر Cloud Function (renewShopSubscription) ──
  static Future<SubscriptionResult> renew({
    required String shopId,
    required String userId,
    required String activationCode,
    required String planKey,
    required int planDays,
    required int planPrice,
    required String planLabel,
    Map<String, dynamic>? currentShopData,
  }) async {
    final normalizedCode = activationCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return const SubscriptionResult.fail('يجب إدخال كود التفعيل');
    }

    try {
      final callable = _functions.httpsCallable('renewShopSubscription');
      final res = await callable.call({
        'shopId': shopId,
        'activationCode': normalizedCode,
        'planKey': planKey,
      });

      final data = res.data;
      if (data is! Map || data['success'] != true) {
        return SubscriptionResult.fail(
          (data is Map ? data['message']?.toString() : null) ??
              'تعذّر تجديد الاشتراك.',
        );
      }

      DateTime resolvedNewEnd = DateTime.now().add(Duration(days: planDays));
      final rawIso = data['newEndDateIso']?.toString();
      if (rawIso != null && rawIso.isNotEmpty) {
        final parsed = DateTime.tryParse(rawIso);
        if (parsed != null) resolvedNewEnd = parsed;
      }

      try {
        final shopName = currentShopData?['name'] as String? ?? 'متجرك';
        await NotificationService().scheduleSubscriptionReminders(
          expiryDate: resolvedNewEnd,
          shopId: shopId,
          shopName: shopName,
        );
      } catch (e) {
        developer.log('scheduleReminders error (non-critical): $e');
      }

      return SubscriptionResult.ok(resolvedNewEnd);
    } on FirebaseFunctionsException catch (e) {
      developer.log('renewSubscription functions error: ${e.message}');
      return SubscriptionResult.fail(e.message ?? 'كود التجديد غير صالح.');
    } catch (e) {
      developer.log('renewSubscription unexpected error: $e');
      return const SubscriptionResult.fail('حدث خطأ غير متوقع. حاول مجدداً.');
    }
  }
}
