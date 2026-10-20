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

  // ✅ Fix #21: أنواع الأكواد المقبولة لتجديد الاشتراك. القاعدة الثابتة: `type`
  // إجباري في كل استعلام تحقق من `activation_codes`. shop_renewal هو نوع التجديد،
  // و shop_activation هو اللي بيولّده تاب الأدمن فعلياً دلوقتي (مفيش مولّد
  // لـ shop_renewal) — فالاتنين مقبولين عشان التجديد الشغّال يفضل شغّال. أي نوع
  // تاني (ad_activation / dealer_listing_fee) مرفوض: كود إعلان ما يجدّدش محل.
  static const List<String> _renewalCodeTypes = [
    'shop_renewal',
    'shop_activation',
  ];

  /// ✅ Fix #21: يحدد وثيقة كود تجديد غير مستخدم، أو null لو الكود غلط/مستخدم/نوعه
  /// مرفوض. استعلام equality لكل نوع مقبول (من غير index مركّب).
  ///
  /// الـ SDK ما بيدعمش query جوه transaction، فالنتيجة دي "تحديد للوثيقة" بس وغير
  /// ملزمة: الفصل الذري بيتم في [renew] بإعادة قراءة الوثيقة بـ tx.get.
  static Future<DocumentReference<Map<String, dynamic>>?> _findUnusedCode(
    String code,
  ) async {
    for (final type in _renewalCodeTypes) {
      final snap = await _db
          .collection('activation_codes')
          .where('code', isEqualTo: code)
          .where('type', isEqualTo: type)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.reference;
    }
    return null;
  }

  // ── 2. التحقق من كود التفعيل (non-binding pre-check) ──────────
  static Future<bool> isCodeValid(String code) async {
    try {
      final codeRef = await _findUnusedCode(code);
      return codeRef != null;
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

      // ✅ Fix #21: كان الاستعلام عن الكود جوه الـ transaction من غير tx.get، فمكنش
      // جزء من قراءاتها: تجديدين متزامنين بنفس الكود يلاقوه الاتنين "غير مستخدم"
      // ويحرقوه (كتابتين "عمياء" مبتتعارضش) فيتجدد الاشتراك مرتين بكود واحد. الـ SDK
      // ما بيدعمش query جوه transaction، فالنمط الصح (زي AdService.redeemAdCode):
      // نحدد الوثيقة بالاستعلام هنا (بنوع مقبول للتجديد)، وجوه الـ transaction
      // نعيد قراءتها بـ tx.get ونتحقق تاني ثم نحرق — فأي حرق متزامن بيجبر الـ SDK
      // يعيد المحاولة ويلاقي الكود اتحرق بالفعل.
      final codeRef = await _findUnusedCode(activationCode.trim());
      if (codeRef == null) {
        throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً');
      }

      // ── Transaction ذرية ─────────────────────────────────────────
      await _db.runTransaction((tx) async {
        // 1. إعادة قراءة الكود بـ tx.get والتحقق ذرياً (لسه غير مستخدم + نوعه مقبول)
        final freshCode = await tx.get(codeRef);
        final freshData = freshCode.data();
        if (!freshCode.exists ||
            freshData == null ||
            freshData['isUsed'] == true ||
            !_renewalCodeTypes.contains(freshData['type'])) {
          throw Exception('كود التفعيل غير صحيح أو مستخدم مسبقاً');
        }

        // 2. حرق الكود
        tx.update(codeRef, {
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
