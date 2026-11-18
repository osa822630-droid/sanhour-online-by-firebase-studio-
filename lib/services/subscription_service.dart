// lib/services/subscription_service.dart
// ✅ توحيد بادئة كود التجديد إلى RNW-XXXX-XXXX مع دعم الأكواد السابقة REN-
// ✅ ربط مدة التجديد (days) والباقة (tier) والسعر (price) بوثيقة الكود في Firestore لمنع التلاعب بالمدة من الواجهة
import 'dart:developer' as developer;
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
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

  static final _db = FirebaseFirestore.instance;

  /// ✅ الباقات الموحدة للاشتراكات في التطبيق
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

  /// ✅ دالة نقية لحساب تاريخ انتهاء الاشتراك الجديد
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
  static const List<String> _renewalCodeTypes = [
    renewalCodeType,
  ];

  /// توليد كود تجديد اشتراك متجر (RNW-XXXX-XXXX) بمعرّف المستند = نص الكود
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

  static Future<DocumentReference<Map<String, dynamic>>?> _findUnusedCode(
    String code,
  ) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    final directRef = _db.collection('activation_codes').doc(normalized);
    final directDoc = await directRef.get();
    if (!directDoc.exists) {
      return null;
    }
    final data = directDoc.data();
    if (data == null ||
        data['isUsed'] == true ||
        !_renewalCodeTypes.contains(data['type'])) {
      return null;
    }
    return directRef;
  }

  static Future<bool> isCodeValid(String code) async {
    try {
      final codeRef = await _findUnusedCode(code);
      return codeRef != null;
    } catch (_) {
      return false;
    }
  }

  // ── 3. تجديد الاشتراك ذرياً مع احترام الباقة والمدة المخزنة في الكود نفسه ──
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
    if (activationCode.trim().isEmpty) {
      return const SubscriptionResult.fail('يجب إدخال كود التفعيل');
    }

    try {
      final now = DateTime.now();
      DateTime? existingEnd;
      if (currentShopData?['subscriptionEndDate'] is Timestamp) {
        existingEnd =
            (currentShopData!['subscriptionEndDate'] as Timestamp).toDate();
      }

      final codeRef = await _findUnusedCode(activationCode.trim());
      if (codeRef == null) {
        throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً');
      }

      late DateTime resolvedNewEnd;
      late String resolvedPlanKey;
      late int resolvedPrice;

      // ── Transaction ذرية ─────────────────────────────────────────
      await _db.runTransaction((tx) async {
        final freshCode = await tx.get(codeRef);
        final freshData = freshCode.data();
        if (!freshCode.exists ||
            freshData == null ||
            freshData['isUsed'] == true ||
            !_renewalCodeTypes.contains(freshData['type'])) {
          throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً');
        }
        final codeExpiresAt = freshData['expiresAt'];
        if (codeExpiresAt is Timestamp &&
            codeExpiresAt.toDate().isBefore(DateTime.now())) {
          throw Exception('انتهت صلاحية كود التجديد');
        }

        // ✅ التحقق من الباقة والمدة المخزنة داخل وثيقة الكود لمنع استخدام كود شهري على باقة سنوية
        final String? codeTier = freshData['tier'] as String?;
        final int? codeDays = (freshData['days'] as num?)?.toInt();
        final int? codePrice = (freshData['price'] as num?)?.toInt();

        if (codeTier != null && tiers.containsKey(codeTier)) {
          resolvedPlanKey = codeTier;
          resolvedPrice = codePrice ?? (tiers[codeTier]!['price'] as int);
          final effectiveDays = codeDays ?? (tiers[codeTier]!['days'] as int);
          resolvedNewEnd = calculateNewExpiry(existingEnd, effectiveDays);
        } else {
          resolvedPlanKey = planKey;
          resolvedPrice = codePrice ?? planPrice;
          final effectiveDays = codeDays ?? planDays;
          resolvedNewEnd = calculateNewExpiry(existingEnd, effectiveDays);
        }

        tx.update(codeRef, {
          'isUsed': true,
          'usedBy': userId,
          'usedAt': FieldValue.serverTimestamp(),
          'shopId': shopId,
        });

        tx.update(_db.collection('shops').doc(shopId), {
          'subscriptionPlan': resolvedPlanKey,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(resolvedNewEnd),
          'subscriptionStatus': 'active',
          'lastRenewalAt': FieldValue.serverTimestamp(),
          'renewedBy': userId,
        });
      });

      // ── سجل الاشتراكات ───────────────────────────────────────────
      try {
        await _db
            .collection('shops')
            .doc(shopId)
            .collection('subscription_history')
            .add({
          'plan': resolvedPlanKey,
          'price': resolvedPrice,
          'startDate': Timestamp.fromDate(now),
          'endDate': Timestamp.fromDate(resolvedNewEnd),
          'renewedBy': userId,
          'activationCode': activationCode.trim().toUpperCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        developer.log('subscription_history write error (non-critical): $e');
      }

      // ── جدولة إشعارات التذكير ──────────────────────────────────
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
    } on Exception catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      developer.log('renewSubscription error: $msg');
      return SubscriptionResult.fail(msg);
    } catch (e) {
      developer.log('renewSubscription unexpected error: $e');
      return const SubscriptionResult.fail('حدث خطأ غير متوقع. حاول مجدداً.');
    }
  }
}
