// lib/services/admin_service.dart
// ✅ P0-4 Fix: توجيه إشعارات الدفع عبر NotificationService.enqueuePushNotification
// ✅ P0-8 Fix: عدم قراءة المفتاح الخام من settings_private/gemini إلى ذاكرة المتصفح/العميل
// ✅ P1-6 Fix: الحذف الكامل لحساب المستخدم وبياناته ومرفقاته عبر purgeAuthUser
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'audit_log_service.dart';
import 'notification_service.dart';

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
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['code'] = data['code'] ?? doc.id;
        data['isUsed'] = data['isUsed'] ?? false;
        return data;
      }).toList();
    } catch (e) {
      developer.log('getAllCodes error: $e', name: 'AdminService');
      return [];
    }
  }

  static Future<String> generateActivationCode(String adminId) async {
    final part1 = _generateSecureString(4);
    final part2 = _generateSecureString(4);
    final code = 'SHOP-$part1-$part2';

    await _firestore.collection('activation_codes').doc(code).set({
      'code': code,
      'isUsed': false,
      'generatedBy': adminId,
      'price': 200,
      'days': 30,
      'tier': 'monthly',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      'type': 'shop_activation',
    });

    await AuditLogService.logActivationCodeGenerated(code,
        generatedBy: adminId);
    return code;
  }

  // ==========================================================
  // 2. الشكاوي
  // ==========================================================

  static Future<void> submitComplaint(Map<String, dynamic> data) async {
    await _firestore.collection('complaints').add({
      ...data,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  static Future<void> replyToComplaint({
    required String complaintId,
    required String reply,
    required String userId,
  }) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'reply': reply,
      'adminReply': reply,
      'repliedBy': userId,
      'repliedAt': FieldValue.serverTimestamp(),
      'status': 'replied',
    });
  }

  // ==========================================================
  // 3. الحذف
  // ==========================================================

  static Future<void> _deleteShopCascadeClientFallback(String shopId) async {
    final shopRef = _firestore.collection('shops').doc(shopId);
    final snapshots = await Future.wait([
      _firestore.collection('products').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('offers').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('services').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('ads').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('reviews').where('targetId', isEqualTo: shopId).get(),
      shopRef.collection('daily_stats').get(),
      shopRef.collection('subscription_history').get(),
    ]);

    final refs = <DocumentReference>[];
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        refs.add(doc.reference);
      }
    }
    refs.add(shopRef);

    for (int i = 0; i < refs.length; i += 400) {
      final chunk = refs.sublist(i, (i + 400).clamp(0, refs.length));
      final batch = _firestore.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  static Future<void> deleteShop(String shopId,
      {String shopName = ''}) async {
    try {
      final callable = _functions.httpsCallable('deleteShopCascade');
      await callable.call({'shopId': shopId});
      await AuditLogService.logShopDeleted(shopId, shopName);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' ||
          e.code == 'unimplemented' ||
          e.code == 'unavailable' ||
          e.code == 'internal') {
        await _deleteShopCascadeClientFallback(shopId);
        await AuditLogService.logShopDeleted(shopId, shopName);
        return;
      }
      throw Exception(_mapFunctionError(e.code));
    } catch (e) {
      try {
        await _deleteShopCascadeClientFallback(shopId);
        await AuditLogService.logShopDeleted(shopId, shopName);
      } catch (fallbackErr) {
        developer.log('deleteShop error: $fallbackErr', name: 'AdminService');
        throw Exception('تعذّر حذف المحل. حاول مجدداً.');
      }
    }
  }

  static Future<void> deleteContent(
      String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
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
    final callable = _functions.httpsCallable('purgeAuthUser');
    await callable.call({'userId': userId});
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
        .set({...data, 'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
    await AuditLogService.logSettingsUpdated(data);
  }

  /// ✅ P0-8 Fix: عدم استرجاع نص مفتاح Gemini السري إلى ذاكرة العميل
  static Future<String> getGeminiApiKey() async => '';

  static Future<void> saveGeminiApiKey(String key) async {
    if (key.trim().isEmpty) return;
    await _firestore.collection('settings_private').doc('gemini').set({
      'apiKey': key.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 12));
    try {
      await _firestore
          .collection('settings')
          .doc('general')
          .update({'geminiApiKey': FieldValue.delete()})
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
    try {
      await AuditLogService.logSettingsUpdated({'geminiApiKey': 'updated'})
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  // ==========================================================
  // 5. تعليق/تفعيل المحلات والمستخدمين
  // ==========================================================

  static Future<void> toggleShopSuspension(
      String shopId, bool currentStatus,
      {String shopName = ''}) async {
    final newStatus = !currentStatus;

    final results = await Future.wait([
      _firestore.collection('products').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('offers').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('services').where('shopId', isEqualTo: shopId).get(),
      _firestore.collection('ads').where('shopId', isEqualTo: shopId).get(),
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
      if (newStatus)
        ...results[3].docs.map((doc) =>
            {'ref': doc.reference, 'data': {'isActive': false}}),
    ];

    for (int i = 0; i < allOps.length; i += 400) {
      final chunk = allOps.sublist(i, (i + 400).clamp(0, allOps.length));
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

    try {
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final ownerId = shopDoc.data()?['ownerId'] as String?;
      final effectiveShopName = shopName.isNotEmpty
          ? shopName
          : (shopDoc.data()?['name'] as String? ?? 'متجرك');

      if (ownerId != null && ownerId.isNotEmpty) {
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
        final title = newStatus ? '⚠️ تم تعليق محلك' : '✅ تم إلغاء تعليق محلك';
        final body = newStatus
            ? 'تم تعليق محل "$effectiveShopName" من قِبَل الإدارة. تواصل مع الدعم.'
            : 'تم إلغاء تعليق محل "$effectiveShopName". يمكنك المتابعة الآن.';

        await _firestore.collection('notifications').add({
          'title': title,
          'body': body,
          'type': 'shop_status',
          'targetUserId': ownerId,
          'fromUserId': adminUid,
          'data': {
            'route': 'merchant',
            'shopId': shopId,
            'channel': 'shop_status',
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await NotificationService.enqueuePushNotification(
          title: title,
          body: body,
          targetUserId: ownerId,
          data: {
            'route': 'merchant',
            'shopId': shopId,
            'channel': 'shop_status',
          },
        );
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

  static Future<void> deleteItemWithNotification({
    required String collection,
    required String docId,
    required String reason,
    String? ownerId,
    String? itemName,
  }) async {
    await deleteContent(collection, docId);
    if (ownerId != null && ownerId.isNotEmpty) {
      try {
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
        final typeLabel = collection == 'products' ? 'المنتج' : 'العرض';
        final nameLabel = (itemName != null && itemName.isNotEmpty)
            ? '"$itemName"'
            : '';
        final title = '⚠️ تم حذف $typeLabel $nameLabel من قِبَل الإدارة';
        final body = 'السبب: $reason';

        await _firestore.collection('notifications').add({
          'title': title,
          'body': body,
          'type': 'content_deleted',
          'targetUserId': ownerId,
          'fromUserId': adminUid,
          'data': {
            'route': 'merchant',
            'channel': 'admin_alerts',
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await NotificationService.enqueuePushNotification(
          title: title,
          body: body,
          targetUserId: ownerId,
          data: {
            'route': 'merchant',
            'channel': 'admin_alerts',
          },
        );
      } catch (e) {
        developer.log('deleteItemWithNotification error: $e',
            name: 'AdminService');
      }
    }
  }
}