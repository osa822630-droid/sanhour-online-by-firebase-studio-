// lib/services/subscription_service.dart
// ✅ استخراج منطق الاشتراك من subscription_screen إلى service مستقلة
// يُيسِّر الاختبار ويُزيل Firestore مباشرةً من الـ widget layer
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

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

  // ── 2. التحقق من كود التفعيل (non-binding pre-check) ──────────
  static Future<bool> isCodeValid(String code) async {
    try {
      final snap = await _db
          .collection('activation_codes')
          .where('code', isEqualTo: code)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── 3. تجديد الاشتراك ذرياً ─────────────────────────────────────
  // ✅ التحقق من الكود وحرقه وتحديث المحل في transaction ذرية واحدة
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
      DateTime currentEnd = now;
      if (currentShopData?['subscriptionEndDate'] != null) {
        final existing =
            (currentShopData!['subscriptionEndDate'] as Timestamp).toDate();
        if (existing.isAfter(now)) currentEnd = existing;
      }
      final newEnd = currentEnd.add(Duration(days: planDays));

      // ── Transaction ذرية ─────────────────────────────────────────
      await _db.runTransaction((tx) async {
        // 1. التحقق من الكود ذرياً
        final codeSnap = await _db
            .collection('activation_codes')
            .where('code', isEqualTo: activationCode.trim())
            .where('isUsed', isEqualTo: false)
            .limit(1)
            .get();

        if (codeSnap.docs.isEmpty) {
          throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً');
        }

        // 2. حرق الكود
        tx.update(codeSnap.docs.first.reference, {
          'isUsed': true,
          'usedBy': userId,
          'usedAt': FieldValue.serverTimestamp(),
          'shopId': shopId,
        });

        // 3. تحديث بيانات المحل
        tx.update(_db.collection('shops').doc(shopId), {
          'subscriptionPlan': planKey,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(newEnd),
          'subscriptionStatus': 'active',
          'lastRenewalAt': FieldValue.serverTimestamp(),
          'renewedBy': userId,
        });
      });

      // ── سجل الاشتراكات (خارج الـ transaction — غير حرج) ─────────
      try {
        await _db
            .collection('shops')
            .doc(shopId)
            .collection('subscription_history')
            .add({
          'plan': planKey,
          'price': planPrice,
          'startDate': Timestamp.fromDate(now),
          'endDate': Timestamp.fromDate(newEnd),
          'renewedBy': userId,
          'activationCode': activationCode.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        developer.log('subscription_history write error (non-critical): $e');
      }

      // ── جدولة إشعارات التذكير ──────────────────────────────────
      try {
        final shopName = currentShopData?['name'] as String? ?? 'متجرك';
        await NotificationService().scheduleSubscriptionReminders(
          expiryDate: newEnd,
          shopId: shopId,
          shopName: shopName,
        );
      } catch (e) {
        developer.log('scheduleReminders error (non-critical): $e');
      }

      return SubscriptionResult.ok(newEnd);
    } on Exception catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      developer.log('renewSubscription error: $msg');
      return SubscriptionResult.fail(msg);
    } catch (e) {
      developer.log('renewSubscription unexpected error: $e');
      return SubscriptionResult.fail('حدث خطأ غير متوقع. حاول مجدداً.');
    }
  }
}
