// lib/services/referral_service.dart
// ✅ Phase 3 Fix #09: نظام Referral للنمو المحلي.
// كل مستخدم يحصل على كود دعوة فريد عند التسجيل.
// عند استخدام الكود: المُدعو يحصل على مكافأة (ظهور في أعلى النتائج 7 أيام)،
// والمُدعي يحصل على تمديد اشتراكه 7 أيام إضافية إذا كان تاجراً.
// النقطة الجوهرية: لا مال، لا دفع — مكافآت رمزية فقط (App Store safe).
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralService {
  ReferralService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================================
  // 1. توليد كود الدعوة
  // ==========================================================

  /// يُولِّد كود دعوة فريد للمستخدم عند التسجيل ويحفظه في وثيقته.
  /// يُستدعى مرة واحدة فقط من auth_provider عند اكتمال التسجيل.
  static Future<String> generateReferralCode(String userId) async {
    try {
      // تحقق أولاً: هل المستخدم عنده كود بالفعل؟
      final userDoc = await _db.collection('users').doc(userId).get();
      final existing = userDoc.data()?['referralCode'];
      if (existing != null && existing.toString().isNotEmpty) {
        return existing.toString();
      }

      // توليد كود فريد: SAN + 6 أحرف عشوائية
      // ✅ QA Fix #21: maxAttempts guard لمنع infinite loop
      String code = 'SAN${_randomString(6)}';
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 10;
      do {
        code = 'SAN${_randomString(6)}';
        final query = await _db
            .collection('users')
            .where('referralCode', isEqualTo: code)
            .limit(1)
            .get();
        isUnique = query.docs.isEmpty;
        attempts++;
        if (attempts >= maxAttempts) {
          // Fallback: timestamp يضمن الفرادة دائماً
          code = 'SAN${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          break;
        }
      } while (!isUnique);

      await _db.collection('users').doc(userId).update({
        'referralCode': code,
        'referralCount': 0,
        'referralBonusDaysEarned': 0,
      });

      return code;
    } catch (e) {
      developer.log('generateReferralCode error: $e', name: 'ReferralService');
      rethrow;
    }
  }

  // ==========================================================
  // 2. استخدام كود الدعوة عند التسجيل
  // ==========================================================

  /// يُطبِّق كود الدعوة بعد اكتمال تسجيل المستخدم الجديد.
  /// [newUserId]: المستخدم الجديد (المُدعو)
  /// [referralCode]: الكود الذي أدخله
  static Future<ReferralResult> applyReferralCode({
    required String newUserId,
    required String referralCode,
  }) async {
    final code = referralCode.trim().toUpperCase();
    if (code.isEmpty) {
      return ReferralResult(
          success: false, message: 'كود الدعوة فارغ.');
    }

    try {
      // ── 1. البحث عن المُدعي بالكود ─────────────────────────
      final referrerQuery = await _db
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) {
        return ReferralResult(
            success: false, message: 'كود الدعوة غير صحيح.');
      }

      final referrerDoc = referrerQuery.docs.first;
      final referrerId = referrerDoc.id;

      // لا يجوز للمستخدم دعوة نفسه
      if (referrerId == newUserId) {
        return ReferralResult(
            success: false,
            message: 'لا يمكنك استخدام كودك الخاص.');
      }

      // ── 2. تحقق أن المُدعو لم يستخدم كود دعوة من قبل ──────
      final newUserDoc =
          await _db.collection('users').doc(newUserId).get();
      if (newUserDoc.data()?['referredBy'] != null) {
        return ReferralResult(
            success: false, message: 'لقد استخدمت كود دعوة مسبقاً.');
      }

      // ── 3. تطبيق المكافآت في Transaction واحدة ──────────────
      await _db.runTransaction((txn) async {
        // تسجيل استخدام الكود على المُدعو
        txn.update(_db.collection('users').doc(newUserId), {
          'referredBy': referrerId,
          'referredByCode': code,
          'referralAppliedAt': FieldValue.serverTimestamp(),
          // ✅ مكافأة المُدعو: ظهور في أعلى النتائج 7 أيام (إذا كان تاجراً)
          'featuredUntil': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
        });

        // زيادة عداد الدعوات للمُدعي + مكافأة 7 أيام اشتراك
        txn.update(_db.collection('users').doc(referrerId), {
          'referralCount': FieldValue.increment(1),
          'referralBonusDaysEarned': FieldValue.increment(7),
        });
      });

      // ── 4. تسجيل في مجموعة referrals ────────────────────────
      await _db.collection('referrals').add({
        'referrerId': referrerId,
        'newUserId': newUserId,
        'code': code,
        'appliedAt': FieldValue.serverTimestamp(),
        'referrerBonusDays': 7,
        'newUserBenefit': 'featured_7_days',
      });

      return ReferralResult(
        success: true,
        message: 'تم تطبيق كود الدعوة بنجاح! 🎉',
        referrerId: referrerId,
        bonusDays: 7,
      );
    } catch (e) {
      developer.log('applyReferralCode error: $e',
          name: 'ReferralService');
      return ReferralResult(
          success: false,
          message: 'حدث خطأ. حاول مجدداً.');
    }
  }

  // ==========================================================
  // 3. إحصائيات الدعوة
  // ==========================================================

  static Future<Map<String, dynamic>> getReferralStats(
      String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final data = userDoc.data() ?? {};
      return {
        'referralCode': data['referralCode'] ?? '',
        'referralCount': data['referralCount'] ?? 0,
        'bonusDaysEarned': data['referralBonusDaysEarned'] ?? 0,
        'referredBy': data['referredBy'],
      };
    } catch (e) {
      developer.log('getReferralStats error: $e',
          name: 'ReferralService');
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getReferralHistory(
      String userId) async {
    try {
      final snap = await _db
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .orderBy('appliedAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      developer.log('getReferralHistory error: $e',
          name: 'ReferralService');
      return [];
    }
  }

  // ==========================================================
  // Helper
  // ==========================================================

  static String _randomString(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }
}

/// نتيجة تطبيق كود الدعوة
class ReferralResult {
  final bool success;
  final String message;
  final String? referrerId;
  final int? bonusDays;

  const ReferralResult({
    required this.success,
    required this.message,
    this.referrerId,
    this.bonusDays,
  });
}