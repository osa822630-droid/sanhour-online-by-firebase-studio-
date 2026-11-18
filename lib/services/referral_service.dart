// lib/services/referral_service.dart
// ✅ توحيد حقول الإحالة (referredId + newUserId و appliedAt + createdAt) للتوافق مع firestore.rules و database_seeder
// ✅ دعم التفعيل عبر Cloud Function redeemReferralCode مع مسار Transaction محلي متوافق مع القواعد الجديدة
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ReferralService {
  ReferralService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ==========================================================
  // 1. توليد كود الدعوة
  // ==========================================================

  static Future<String> generateReferralCode(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final existing = userDoc.data()?['referralCode'];
      if (existing != null && existing.toString().isNotEmpty) {
        return existing.toString();
      }

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
          code =
              'SAN${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          break;
        }
      } while (!isUnique);

      await _db.collection('users').doc(userId).set({
        'referralCode': code,
        'referralCount': 0,
        'referralBonusDaysEarned': 0,
      }, SetOptions(merge: true));

      return code;
    } catch (e) {
      developer.log('generateReferralCode error: $e', name: 'ReferralService');
      rethrow;
    }
  }

  // ==========================================================
  // 2. استخدام كود الدعوة عند التسجيل
  // ==========================================================

  static Future<ReferralResult> applyReferralCode({
    required String newUserId,
    required String referralCode,
  }) async {
    final code = referralCode.trim().toUpperCase();
    if (code.isEmpty) {
      return const ReferralResult(
          success: false, message: 'كود الدعوة فارغ.');
    }

    // محاولة التنفيذ عبر Cloud Function أولاً
    try {
      final callable = _functions.httpsCallable('redeemReferralCode');
      final res = await callable.call({'referralCode': code});
      final data = res.data;
      if (data is Map) {
        final ok = data['success'] == true;
        final msg = (data['message'] as String?) ??
            (ok ? 'تم تطبيق كود الدعوة بنجاح! 🎉' : 'تعذّر تطبيق كود الدعوة.');
        return ReferralResult(
          success: ok,
          message: msg,
          bonusDays: (data['bonusDays'] as num?)?.toInt() ?? (ok ? 7 : null),
        );
      }
    } catch (_) {
      // المتابعة إلى المسار المحلي المتوافق مع firestore.rules في حال عدم توفر الدالة السحابية
    }

    try {
      // ── 1. البحث عن المُدعي بالكود ─────────────────────────
      final referrerQuery = await _db
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) {
        return const ReferralResult(
            success: false, message: 'كود الدعوة غير صحيح.');
      }

      final referrerDoc = referrerQuery.docs.first;
      final referrerId = referrerDoc.id;

      if (referrerId == newUserId) {
        return const ReferralResult(
            success: false, message: 'لا يمكنك استخدام كودك الخاص.');
      }

      // ── 2. تحقق أن المُدعو لم يستخدم كود دعوة من قبل ──────
      final newUserDoc = await _db.collection('users').doc(newUserId).get();
      if (newUserDoc.data()?['referredBy'] != null) {
        return const ReferralResult(
            success: false, message: 'لقد استخدمت كود دعوة مسبقاً.');
      }

      // ── 3. تطبيق المكافآت في Transaction واحدة ──────────────
      await _db.runTransaction((txn) async {
        final referrerSnap =
            await txn.get(_db.collection('users').doc(referrerId));
        final prevCount =
            (referrerSnap.data()?['referralCount'] as num?)?.toInt() ?? 0;
        final prevDays =
            (referrerSnap.data()?['referralBonusDaysEarned'] as num?)
                    ?.toInt() ??
                0;

        txn.update(_db.collection('users').doc(newUserId), {
          'referredBy': referrerId,
          'referredByCode': code,
          'referralAppliedAt': FieldValue.serverTimestamp(),
          'featuredUntil':
              DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        });

        // ✅ تحديث الحقلين المسموح بهما في isReferralRewardBump داخل firestore.rules
        txn.update(_db.collection('users').doc(referrerId), {
          'referralCount': prevCount + 1,
          'referralBonusDaysEarned': prevDays + 7,
        });
      });

      // ── 4. تسجيل في مجموعة referrals بالحقلين referredId و newUserId معاً ──
      final ts = FieldValue.serverTimestamp();
      await _db.collection('referrals').add({
        'referrerId': referrerId,
        'referredId': newUserId,
        'newUserId': newUserId,
        'code': code,
        'appliedAt': ts,
        'createdAt': ts,
        'bonusDays': 7,
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
      developer.log('applyReferralCode error: $e', name: 'ReferralService');
      return const ReferralResult(
          success: false, message: 'حدث خطأ. حاول مجدداً.');
    }
  }

  // ==========================================================
  // 3. إحصائيات الدعوة
  // ==========================================================

  static Future<Map<String, dynamic>> getReferralStats(String userId) async {
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
      developer.log('getReferralStats error: $e', name: 'ReferralService');
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
      developer.log('getReferralHistory error: $e', name: 'ReferralService');
      return [];
    }
  }

  static String _randomString(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }
}

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