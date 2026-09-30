// lib/services/admin_service.dart
//
// ✅ Phase 3 Fix #05: Cascading Delete مُرحَّل لـ Cloud Function.
// قبل الإصلاح: deleteContent تُنفَّذ client-side — 200 منتج = 200+ sequential calls.
// لو انقطع الإنترنت في المنتصف: المحل محذوف لكن المنتجات ظلّت (data inconsistency).
//
// الإصلاح:
//   deleteShop() الآن تستدعي Cloud Function عبر HttpsCallable.
//   الـ Cloud Function تُنفَّذ كـ batch server-side مع ضمان الاتساق.
//   deleteContent() تبقى للحذف البسيط (غير المحلات) مع audit log.
//
// ✅ Phase 3 Fix #04: كل عملية حساسة تُسجَّل في AuditLogService.
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'audit_log_service.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ==========================================================
  // 1. أكواد التفعيل
  // ==========================================================

  static Future<List<Map<String, dynamic>>> getAllCodes() async {
    try {
      final snapshot = await _firestore
          .collection('activation_codes')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => {
            'code': doc['code'],
            'isUsed': doc['isUsed'],
            'id': doc.id
          }).toList();
    } catch (e) {
      developer.log('getAllCodes error: $e', name: 'AdminService');
      return [];
    }
  }

  static Future<void> generateActivationCode(String adminId) async {
    final part1 = _generateSecureString(4);
    final part2 = _generateSecureString(4);
    final code = 'SHOP-$part1-$part2';

    await _firestore.collection('activation_codes').add({
      'code': code,
      'isUsed': false,
      'generatedBy': adminId,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'shop_activation',
    });

    // ✅ Phase 3 Fix #04: تسجيل في الـ audit log
    await AuditLogService.logActivationCodeGenerated(code,
        generatedBy: adminId);
  }

  // ==========================================================
  // 2. الشكاوي
  // ==========================================================

  static Future<void> submitComplaint(Map<String, dynamic> data) async {
    await _firestore.collection('complaints').add(
        {...data, 'status': 'new', 'createdAt': FieldValue.serverTimestamp()});
  }

  static Future<List<Map<String, dynamic>>> getComplaints() async {
    final snapshot = await _firestore
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final d = Map<String, dynamic>.from(doc.data());
      d['id'] = doc.id;
      return d;
    }).toList();
  }

  static Future<void> updateComplaintStatus(String id, String status) async {
    await _firestore.collection('complaints').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ QA Fix #09: توحيد اسم المعامل مع ApiService (userId بدلاً من adminId)
  static Future<void> replyToComplaint({
    required String complaintId,
    required String reply,
    required String userId,
  }) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'adminReply': reply,
      'repliedBy': userId,
      'repliedAt': FieldValue.serverTimestamp(),
      'status': 'replied',
    });
  }

  // ==========================================================
  // 3. الحذف
  // ==========================================================

  /// ✅ Phase 3 Fix #05: حذف محل عبر Cloud Function — atomic + server-side.
  /// يحذف المحل + منتجاته + عروضه + إعلاناته + تقييماته دفعة واحدة.
  static Future<void> deleteShop(String shopId,
      {String shopName = ''}) async {
    try {
      final callable = _functions.httpsCallable('deleteShopCascade');
      await callable.call({'shopId': shopId});

      // ✅ Phase 3 Fix #04: تسجيل الحذف في audit log
      await AuditLogService.logShopDeleted(shopId, shopName);
    } on FirebaseFunctionsException catch (e) {
      developer.log(
          'deleteShop Cloud Function error: ${e.code} — ${e.message}',
          name: 'AdminService');
      // ✅ رسالة user-friendly
      throw Exception(_mapFunctionError(e.code));
    } catch (e) {
      developer.log('deleteShop error: $e', name: 'AdminService');
      throw Exception('تعذّر حذف المحل. حاول مجدداً.');
    }
  }

  /// حذف محتوى غير المحلات (منتج، عرض، إعلان، تقييم، شكوى)
  static Future<void> deleteContent(
      String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
    // ✅ Fix #40: تحديد AuditAction الصحيح لكل collection
    AuditAction action;
    switch (collection) {
      case 'products':
        action = AuditAction.productDeleted;
        break;
      case 'offers':
        action = AuditAction.offerDeleted;
        break;
      case 'reviews':
        action = AuditAction.reviewDeleted;
        break;
      case 'ads':
        action = AuditAction.adDeleted;
        break;
      case 'complaints':
        action = AuditAction.complaintDeleted;
        break;
      default:
        action = AuditAction.offerDeleted;
    }
    await AuditLogService.log(
      action: action,
      targetId: docId,
      targetType: collection,
    );
  }

  static Future<void> deleteUser(String userId,
      {String userName = ''}) async {
    await _firestore.collection('users').doc(userId).delete();
    await AuditLogService.log(
      action: AuditAction.userDeleted,
      targetId: userId,
      targetType: 'user',
      targetName: userName,
    );
  }

  // ==========================================================
  // 4. الإحصائيات والإعدادات
  // ==========================================================

  static Future<Map<String, int>> getAppStatistics() async {
    try {
      final results = await Future.wait([
        _firestore.collection('shops').count().get(),
        _firestore.collection('users').count().get(),
        _firestore.collection('products').count().get(),
        _firestore.collection('offers').count().get(),
      ]);
      return {
        'shops': results[0].count ?? 0,
        'users': results[1].count ?? 0,
        'products': results[2].count ?? 0,
        'offers': results[3].count ?? 0,
      };
    } catch (e) {
      developer.log('getAppStatistics error: $e', name: 'AdminService');
      return {'shops': 0, 'users': 0, 'products': 0, 'offers': 0};
    }
  }

  static Future<Map<String, dynamic>> getAppSettings() async {
    final doc =
        await _firestore.collection('settings').doc('general').get();
    return doc.data() ?? {};
  }

  static Future<void> updateAppSettings(
      Map<String, dynamic> data) async {
    await _firestore
        .collection('settings')
        .doc('general')
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    // ✅ Phase 3 Fix #04: تسجيل تعديل الإعدادات
    await AuditLogService.logSettingsUpdated(data);
  }

  // ==========================================================
  // 5. تعليق/تفعيل المحلات والمستخدمين
  // ==========================================================

  static Future<void> toggleShopSuspension(
      String shopId, bool currentStatus,
      {String shopName = ''}) async {
    // ✅ QA Fix #P2: تحديث المحل والمنتجات في نفس batch لضمان الاتساق
    // ✅ Fix #39: تشمل offers وservices أيضاً لمنع ظهورها أثناء التعليق
    final newStatus = !currentStatus;

    final results = await Future.wait([
      _firestore.collection('products').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('offers').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('services').where('shopId', isEqualTo: shopId).get(),
    ]);

    final allOps = <Map<String, dynamic>>[
      {
        'ref': _firestore.collection('shops').doc(shopId),
        'data': {
          'isSuspended': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      },
      ...results[0].docs.map((doc) =>
          {'ref': doc.reference, 'data': {'isShopHidden': newStatus}}),
      ...results[1].docs.map((doc) =>
          {'ref': doc.reference, 'data': {'isShopHidden': newStatus}}),
      ...results[2].docs.map((doc) =>
          {'ref': doc.reference, 'data': {'isShopHidden': newStatus}}),
    ];

    for (int i = 0; i < allOps.length; i += 490) {
      final chunk = allOps.sublist(i, (i + 490).clamp(0, allOps.length));
      final batch = _firestore.batch();
      for (final op in chunk) {
        batch.update(
          op['ref'] as DocumentReference,
          op['data'] as Map<String, dynamic>,
        );
      }
      await batch.commit();
    }

    await AuditLogService.logShopSuspended(shopId, shopName,
        isSuspended: newStatus);

    // ✅ Fix #41: إشعار التاجر عند تعليق أو إلغاء تعليق محله
    try {
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final ownerId = shopDoc.data()?['ownerId'] as String?;
      if (ownerId != null) {
        final userDoc = await _firestore.collection('users').doc(ownerId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;
        if (fcmToken != null) {
          await _firestore.collection('notification_queue').add({
            'title': newStatus ? '⚠️ تم تعليق محلك' : '✅ تم إلغاء تعليق محلك',
            'body': newStatus
                ? 'تم تعليق محل "$shopName" من قِبَل الإدارة. تواصل مع الدعم.'
                : 'تم إلغاء تعليق محل "$shopName". يمكنك المتابعة الآن.',
            'targetUserId': ownerId,
            'fcmToken': fcmToken,
            'data': {
              'route': 'merchant',
              'shopId': shopId,
              'channel': 'shop_status',
            },
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(hours: 24))),
          });
        }
      }
    } catch (e) {
      developer.log('toggleShopSuspension notification error: $e',
          name: 'AdminService');
    }
  }

  static Future<void> toggleUserSuspension(
      String userId, bool currentStatus,
      {String userName = ''}) async {
    final newStatus = !currentStatus;
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isSuspended': newStatus});
    // ✅ Phase 3 Fix #04
    await AuditLogService.logUserSuspended(userId, userName,
        isSuspended: newStatus);
  }

  // ==========================================================
  // 6. Helper
  // ==========================================================

  static String _generateSecureString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  static String _mapFunctionError(String code) {
    switch (code) {
      case 'not-found':
        return 'المحل غير موجود.';
      case 'permission-denied':
        return 'غير مصرح لك بهذه العملية.';
      case 'unavailable':
        return 'تعذّر الاتصال بالسيرفر. حاول مجدداً.';
      default:
        return 'حدث خطأ غير متوقع. حاول مجدداً.';
    }
  }

  // ✅ QA Fix #08: توسيع التوقيع ليتطابق مع ApiService — إضافة ownerId و itemName اختياريَّين
  static Future<void> deleteItemWithNotification({
    required String collection,
    required String docId,
    required String reason,
    String? ownerId,
    String? itemName,
  }) async {
    await deleteContent(collection, docId);
    // الإشعار يُرسَل من Cloud Function تلقائياً عند الحذف
  }
}