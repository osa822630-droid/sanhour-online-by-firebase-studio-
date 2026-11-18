// lib/services/dealer_listing_service.dart
// ✅ P1-7 Fix: التحقق من كود رسوم إعلان الديلر وحرقه يتم عبر Cloud Functions (checkActivationCode & publishPaidDealerListing)
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'audit_log_service.dart';

class DealerFeeCodeException implements Exception {
  final String userMessage;
  const DealerFeeCodeException(this.userMessage);

  @override
  String toString() => 'DealerFeeCodeException: $userMessage';
}

class DealerListingService {
  DealerListingService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static const String feeCodeType = 'dealer_listing_fee';
  static const int extraListingFee = 100;

  static const DealerFeeCodeException _invalidCode =
      DealerFeeCodeException('كود الدفع غير صحيح أو مستخدم مسبقاً.');

  static Future<String> generateFeeCode({String adminId = 'admin'}) async {
    final code = 'DLR-${_secureString(4)}-${_secureString(4)}';

    await _firestore.collection('activation_codes').doc(code).set({
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

  /// يتحقق من صلاحية كود الرسوم عبر Cloud Function قبل رفع صورة الإعلان
  static Future<DocumentReference<Map<String, dynamic>>> findFeeCode(
      String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw _invalidCode;

    try {
      final callable = _functions.httpsCallable('checkActivationCode');
      final res = await callable.call({
        'code': normalized,
        'expectedType': feeCodeType,
      });
      final data = res.data;
      if (data is! Map || data['valid'] != true) {
        final msg = (data is Map ? data['message']?.toString() : null) ??
            _invalidCode.userMessage;
        throw DealerFeeCodeException(msg);
      }
      return _firestore.collection('activation_codes').doc(normalized);
    } on FirebaseFunctionsException catch (e) {
      throw DealerFeeCodeException(e.message ?? _invalidCode.userMessage);
    } catch (e) {
      if (e is DealerFeeCodeException) rethrow;
      throw _invalidCode;
    }
  }

  /// يحرق كود الرسوم وينشر الإعلان ذرياً على الخادم عبر Cloud Function
  static Future<void> publishPaidListing({
    required DocumentReference<Map<String, dynamic>> codeRef,
    required String userId,
    required Map<String, dynamic> listing,
  }) async {
    try {
      final callable = _functions.httpsCallable('publishPaidDealerListing');
      final res = await callable.call({
        'code': codeRef.id,
        'listing': listing,
      });
      final data = res.data;
      if (data is! Map || data['success'] != true) {
        throw _invalidCode;
      }
    } on FirebaseFunctionsException catch (e) {
      throw DealerFeeCodeException(e.message ?? _invalidCode.userMessage);
    } catch (e) {
      if (e is DealerFeeCodeException) rethrow;
      throw _invalidCode;
    }
  }

  static String _secureString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }
}
