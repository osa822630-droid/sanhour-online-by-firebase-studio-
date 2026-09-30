// lib/services/audit_log_service.dart
// ✅ Phase 3 Fix #04: Admin Audit Trail
// كل عملية حساسة يعملها الأدمن (حذف، تعليق، تفعيل كود، تعديل إعدادات)
// تُسجَّل في مجموعة admin_audit_log في Firestore.
// هذا مطلوب لـ App Store compliance والحوكمة الداخلية.
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// نوع العملية المُسجَّلة
enum AuditAction {
  shopCreated,
  shopDeleted,
  shopSuspended,
  shopUnsuspended,
  userSuspended,
  userUnsuspended,
  userDeleted,
  activationCodeGenerated,
  activationCodeUsed,
  settingsUpdated,
  productDeleted,
  offerDeleted,
  // ✅ Fix #40: قيم جديدة لأنواع المحتوى المختلفة
  reviewDeleted,
  adDeleted,
  complaintDeleted,
  contentReported,
  complaintResolved,
}

class AuditLogService {
  AuditLogService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'admin_audit_log';

  // ==========================================================
  // دالة التسجيل الرئيسية
  // ==========================================================

  /// يُسجِّل عملية حساسة في Firestore audit log.
  /// لا يُوقف تنفيذ الكود الأصلي إذا فشل — يُسجِّل خطأ فقط.
  static Future<void> log({
    required AuditAction action,
    required String targetId,
    String? targetType,
    String? targetName,
    Map<String, dynamic>? metadata,
    // ✅ Fix #8: قبول adminId صريح لدعم Mock users وتجنب الاعتماد على _auth.currentUser فقط
    String? adminId,
  }) async {
    try {
      final adminUid = adminId ?? _auth.currentUser?.uid ?? 'mock_admin';
      await _firestore.collection(_collection).add({
        'action': action.name,
        'adminUid': adminUid,
        'adminId': adminUid,
        'targetId': targetId,
        'targetType': targetType,
        'targetName': targetName,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'flutter_app',
      });
    } catch (e, s) {
      developer.log('AuditLog write error: $e',
          name: 'AuditLogService', error: e, stackTrace: s);
    }
  }

  // ==========================================================
  // Helper factories للأنواع الشائعة
  // ==========================================================

  static Future<void> logShopDeleted(String shopId, String shopName) =>
      log(
        action: AuditAction.shopDeleted,
        targetId: shopId,
        targetType: 'shop',
        targetName: shopName,
      );

  static Future<void> logShopSuspended(String shopId, String shopName,
          {required bool isSuspended}) =>
      log(
        action: isSuspended
            ? AuditAction.shopSuspended
            : AuditAction.shopUnsuspended,
        targetId: shopId,
        targetType: 'shop',
        targetName: shopName,
        metadata: {'isSuspended': isSuspended},
      );

  static Future<void> logUserSuspended(String userId, String userName,
          {required bool isSuspended}) =>
      log(
        action: isSuspended
            ? AuditAction.userSuspended
            : AuditAction.userUnsuspended,
        targetId: userId,
        targetType: 'user',
        targetName: userName,
        metadata: {'isSuspended': isSuspended},
      );

  static Future<void> logActivationCodeGenerated(String code,
          {required String generatedBy}) =>
      log(
        action: AuditAction.activationCodeGenerated,
        targetId: code,
        targetType: 'activation_code',
        metadata: {'generatedBy': generatedBy},
      );

  static Future<void> logSettingsUpdated(Map<String, dynamic> changes) =>
      log(
        action: AuditAction.settingsUpdated,
        targetId: 'app_settings',
        targetType: 'settings',
        metadata: {'changes': changes},
      );

  // ==========================================================
  // جلب السجلات للأدمن
  // ==========================================================

  /// يجلب آخر [limit] سجل من الـ audit log
  static Future<List<Map<String, dynamic>>> getRecentLogs(
      {int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      developer.log('AuditLog fetch error: $e', name: 'AuditLogService');
      return [];
    }
  }

  /// Stream للأدمن Dashboard — يعرض السجلات فوراً عند إضافة أي منها
  static Stream<List<Map<String, dynamic>>> auditLogStream(
      {int limit = 100}) {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }
}
