// lib/services/dealer_listing_service.dart
// ✅ Item #35: رسوم إعلان الديلر الإضافي (100 جنيه) عبر كود dealer_listing_fee.
//
// الدفع بيتم خارج التطبيق (تسوية مباشرة مع الإدارة) والإدارة بتسلّم المستخدم
// كود من نوع dealer_listing_fee بعد السداد؛ الكود بيتحرق ذرّياً مع نشر الإعلان.
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'audit_log_service.dart';

/// خطأ كود رسوم إعلان الديلر — رسالته عربية جاهزة للعرض للمستخدم
/// (كود غير صحيح / مستخدم / منتهي) بدل رسالة عامة بتخفي السبب.
class DealerFeeCodeException implements Exception {
  final String userMessage;
  const DealerFeeCodeException(this.userMessage);

  @override
  String toString() => 'DealerFeeCodeException: $userMessage';
}

class DealerListingService {
  DealerListingService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// قيمة حقل type لأكواد رسوم الإعلان الإضافي داخل activation_codes.
  static const String feeCodeType = 'dealer_listing_fee';

  /// رسوم الإعلان الإضافي في نفس الشهر (جنيه).
  static const int extraListingFee = 100;

  static const DealerFeeCodeException _invalidCode =
      DealerFeeCodeException('كود الدفع غير صحيح أو مستخدم مسبقاً.');

  /// يولّد كود رسوم إعلان ديلر حقيقياً في نظام activation_codes الموحّد
  /// (type: dealer_listing_fee) بصلاحية 30 يوماً، ويسجّل التوليد في audit log،
  /// ثم يرجّع نص الكود للأدمن.
  static Future<String> generateFeeCode({String adminId = 'admin'}) async {
    final code = 'DLR-${_secureString(4)}-${_secureString(4)}';

    await _firestore.collection('activation_codes').add({
      'code': code,
      'type': feeCodeType,
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

  /// يدوّر على كود رسوم صالح (غير مستخدم ولم تنتهِ صلاحيته) ويرجّع مرجعه.
  ///
  /// الاستعلام equality فقط (بلا index مركّب). بتتنادى قبل رفع صورة الإعلان
  /// عشان كود غلط ما يسيبش صورة يتيمة في الـ Storage؛ الحرق الفعلي بيحصل في
  /// [publishPaidListing]. بترمي [DealerFeeCodeException] برسالة عربية.
  static Future<DocumentReference<Map<String, dynamic>>> findFeeCode(
      String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw _invalidCode;

    final snap = await _firestore
        .collection('activation_codes')
        .where('code', isEqualTo: normalized)
        .where('type', isEqualTo: feeCodeType)
        .where('isUsed', isEqualTo: false)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw _invalidCode;

    _assertUsable(snap.docs.first.data());
    return snap.docs.first.reference;
  }

  /// يحرق كود الرسوم وينشر الإعلان في transaction واحدة: الـ transaction بتعيد
  /// قراءة الكود بـ `tx.get` فلا يقدر طلبان متزامنان حرق نفس الكود، ولو فشل نشر
  /// الإعلان الكود ما بيتحرقش (ولو الكود اتحرق في نفس اللحظة الإعلان ما بيتنشرش).
  static Future<void> publishPaidListing({
    required DocumentReference<Map<String, dynamic>> codeRef,
    required String userId,
    required Map<String, dynamic> listing,
  }) async {
    final listingRef = _firestore.collection('dealer_listings').doc();

    await _firestore.runTransaction((tx) async {
      final fresh = await tx.get(codeRef);
      if (!fresh.exists) throw _invalidCode;
      _assertUsable(fresh.data());

      tx.update(codeRef, {
        'isUsed': true,
        'usedBy': userId,
        'usedAt': FieldValue.serverTimestamp(),
      });
      tx.set(listingRef, {
        ...listing,
        'isPaid': true,
        'feeCodeId': codeRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// فحص صلاحية الكود: النوع الصحيح، غير مستخدم، ولم تنتهِ صلاحيته.
  static void _assertUsable(Map<String, dynamic>? data) {
    if (data == null || data['isUsed'] == true || data['type'] != feeCodeType) {
      throw _invalidCode;
    }
    final expiresAt = data['expiresAt'];
    if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
      throw const DealerFeeCodeException('انتهت صلاحية كود الدفع.');
    }
  }

  static String _secureString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }
}
