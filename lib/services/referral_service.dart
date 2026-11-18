// lib/services/referral_service.dart
// ✅ P0-6 Fix: توجيه توليد وتفعيل أكواد الإحالة حصرياً عبر Cloud Functions لمنع تزوير المكافآت
// ✅ إضافة getOrCreateCode و getReferralCount للتوافق التام مع account_edit_screen
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ReferralService {
  ReferralService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ==========================================================
  // 1. توليد أو جلب كود الدعوة
  // ==========================================================

  static Future<String> getOrCreateCode(String userId) =>
      generateReferralCode(userId);

  static Future<int> getReferralCount(String userId) async {
    final stats = await getReferralStats(userId);
    return (stats['referralCount'] as num?)?.toInt() ?? 0;
  }

  static Future<String> generateReferralCode(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final existing = userDoc.data()?['referralCode'];
      if (existing != null && existing.toString().isNotEmpty) {
        return existing.toString();
      }

      // استدعاء Cloud Function لتوليد كود فريد على الخادم دون الحاجة لفهرسة قائمة المستخدمين في العميل
      try {
        final callable = _functions.httpsCallable('getOrCreateReferralCode');
        final res = await callable.call();
        final data = res.data;
        if (data is Map && data['referralCode'] != null) {
          return data['referralCode'].toString();
        }
      } catch (_) {}

      final code = 'SAN${_randomString(6)}';
      await _db.collection('users').doc(userId).update({
        'referralCode': code,
      });
      return code;
    } catch (e) {
      developer.log('generateReferralCode error: $e', name: 'ReferralService');
      rethrow;
    }
  }

  // ==========================================================
  // 2. استخدام كود الدعوة عبر Cloud Function حصرياً (P0-6 Fixed)
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
      return const ReferralResult(
        success: false,
        message: 'تعذّر التحقق من كود الدعوة.',
      );
    } catch (e) {
      developer.log('applyReferralCode error: $e', name: 'ReferralService');
      return const ReferralResult(
          success: false, message: 'تعذّر تطبيق كود الدعوة. حاول مجدداً.');
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