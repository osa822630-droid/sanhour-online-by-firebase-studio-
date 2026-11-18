// lib/services/ad_service.dart
// ✅ P1-7 Fix: حرق كود الإعلان يتم ذرياً عبر Cloud Function (redeemAdCode) بعد التحقق من ملكية المتجر
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ad_model.dart';
import 'audit_log_service.dart';
import 'media_upload_service.dart';

class AdCodeException implements Exception {
  final String userMessage;
  const AdCodeException(this.userMessage);

  @override
  String toString() => 'AdCodeException: $userMessage';
}

class AdsPageResult {
  final List<AdModel> ads;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool failed;

  const AdsPageResult({
    this.ads = const [],
    this.lastDocument,
    this.hasMore = false,
    this.failed = false,
  });
}

class AdService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<List<AdModel>> getActiveAds({
    String? location,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .limit(limit);

      if (location != null) {
        query = query.where('displayLocations', arrayContains: location);
      }

      final snapshot = await query.get();
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) =>
              AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((ad) => ad.expiresAt == null || ad.expiresAt!.isAfter(now))
          .toList();
    } catch (e, s) {
      developer.log('getActiveAds error: $e',
          name: 'AdService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<void> incrementAdClickCount(String adId) async {
    try {
      await _firestore
          .collection('ads')
          .doc(adId)
          .update({'clickCount': FieldValue.increment(1)});
    } catch (e, s) {
      developer.log('incrementAdClickCount error: $e',
          name: 'AdService', error: e, stackTrace: s);
    }
  }

  static Future<String> _uploadAdImage(
    File file, {
    void Function(double fraction)? onProgress,
  }) {
    return MediaUploadService.uploadFile(
      file: file,
      folder: 'ad_images',
      kind: MediaKind.image,
      onProgress: onProgress == null ? null : (p) => onProgress(p.fraction),
    );
  }

  static Future<void> createAd({
    required List<File> imageFiles,
    required String targetType,
    required String text,
    String? targetId,
    String? activationCode,
    int durationDays = 7,
    int coverIndex = 0,
    String? shopId,
    List<String> displayLocations = const ['home', 'splash', 'ads_screen'],
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) async {
    if (imageFiles.isEmpty) {
      throw Exception('يجب إضافة صورة واحدة على الأقل للإعلان');
    }

    final imageUrls = await Future.wait(List.generate(imageFiles.length, (i) {
      return _uploadAdImage(
        imageFiles[i],
        onProgress: onImageProgress == null
            ? null
            : (f) => onImageProgress(i, f),
      );
    }));

    final validCoverIndex = coverIndex.clamp(0, imageUrls.length - 1);
    final coverImageUrl = imageUrls[validCoverIndex];

    if (activationCode != null &&
        activationCode.trim().isNotEmpty &&
        shopId != null &&
        shopId.trim().isNotEmpty) {
      await redeemAdCode(
        code: activationCode,
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        shopId: shopId,
        adPayload: {
          'imageUrls': imageUrls,
          'coverImageIndex': validCoverIndex,
          'imageUrl': coverImageUrl,
          'text': text,
          'actionButtonText': 'اعرف أكثر',
          'targetType': targetType,
          'targetId': targetId,
          'displayLocations': displayLocations,
        },
      );
      return;
    }

    if (shopId != null) {
      final existing = await _firestore
          .collection('ads')
          .where('shopId', isEqualTo: shopId)
          .where('isMainActive', isEqualTo: true)
          .get();
      for (final doc in existing.docs) {
        await doc.reference.update({
          'isMainActive': false,
          'displayLocations': ['ads_screen'],
        });
      }
    }

    final docRef = _firestore.collection('ads').doc();
    final expiresTs = durationDays > 0
        ? Timestamp.fromDate(DateTime.now().add(Duration(days: durationDays)))
        : null;
    await docRef.set({
      'id': docRef.id,
      'imageUrls': imageUrls,
      'coverImageIndex': validCoverIndex,
      'imageUrl': coverImageUrl,
      'text': text,
      'actionButtonText': 'اعرف أكثر',
      'targetType': targetType,
      'targetId': targetId,
      'activationCode': activationCode,
      'isActive': true,
      'isMainActive': true,
      'clickCount': 0,
      'shopId': shopId,
      'displayLocations': displayLocations,
      'expiresAt': expiresTs,
      'endDate': expiresTs,
      'createdAt': FieldValue.serverTimestamp(),
      'startDate': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<AdModel>> getAllAds() async {
    try {
      final snap = await _firestore
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((d) => AdModel.fromMap(d.data(), d.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static const Duration archiveWindow = Duration(days: 183);
  static const int archivePageSize = 20;

  static Future<AdsPageResult> getArchivePage({
    required bool newestFirst,
    DocumentSnapshot? startAfter,
    int pageSize = archivePageSize,
  }) async {
    try {
      final cutoff =
          Timestamp.fromDate(DateTime.now().subtract(archiveWindow));
      Query query = _firestore
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: cutoff)
          .orderBy('createdAt', descending: newestFirst);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snap = await query.limit(pageSize).get();
      return AdsPageResult(
        ads: snap.docs
            .map((doc) =>
                AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList(),
        lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == pageSize,
      );
    } catch (e, s) {
      developer.log('getArchivePage error: $e',
          name: 'AdService', error: e, stackTrace: s);
      return const AdsPageResult(failed: true);
    }
  }

  static Future<void> updateAdLocations(
      String adId, List<String> locations) async {
    await _firestore.collection('ads').doc(adId).update({
      'displayLocations': locations,
      'isMainActive':
          locations.contains('home') || locations.contains('splash'),
    });
  }

  static Future<String> generateAdCode({String adminId = 'admin'}) async {
    final code = 'AD-${_secureString(4)}-${_secureString(4)}';

    await _firestore.collection('activation_codes').doc(code).set({
      'code': code,
      'type': 'ad_activation',
      'price': 50,
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

  static Future<String?> redeemAdCode({
    required String code,
    required String userId,
    required String shopId,
    Map<String, dynamic>? adPayload,
    String? adId,
  }) async {
    const invalid = AdCodeException('كود الإعلان غير صحيح أو مستخدم مسبقاً.');
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw invalid;

    try {
      final callable = _functions.httpsCallable('redeemAdCode');
      final res = await callable.call({
        'code': normalized,
        'shopId': shopId,
        if (adPayload != null) 'adPayload': adPayload,
        if (adId != null) 'adId': adId,
      });
      final data = res.data;
      if (data is! Map || data['success'] != true) {
        throw invalid;
      }
      return data['adId']?.toString();
    } on FirebaseFunctionsException catch (e) {
      throw AdCodeException(e.message ?? invalid.userMessage);
    } catch (e) {
      if (e is AdCodeException) rethrow;
      throw invalid;
    }
  }

  static String _secureString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  static const double videoPricePerMinute = 50.0;
  static const int maxVideoDurationMinutes = 3;

  static double calculateVideoCost(int durationSeconds) {
    final minutes = (durationSeconds / 60).ceil();
    return minutes * videoPricePerMinute;
  }

  static String? validateVideoDuration(int durationSeconds) {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes > maxVideoDurationMinutes) {
      return 'مدة الفيديو تتجاوز الحد المسموح ($maxVideoDurationMinutes دقائق). '
          'الفيديو الحالي: $minutes دقيقة.';
    }
    return null;
  }

  static Future<Map<String, dynamic>> uploadVideoAd({
    required File videoFile,
    required String shopId,
    required String shopOwnerId,
    required int durationSeconds,
    required String description,
    List<String> displayLocations = const ['home', 'ads_screen'],
    void Function(double fraction)? onProgress,
  }) async {
    final durationError = validateVideoDuration(durationSeconds);
    if (durationError != null) {
      return {'success': false, 'error': durationError};
    }

    final cost = calculateVideoCost(durationSeconds);
    final durationMinutes = (durationSeconds / 60).ceil();

    try {
      final videoUrl = await MediaUploadService.uploadFile(
        file: videoFile,
        folder: 'ads/$shopId/pending',
        kind: MediaKind.video,
        onProgress:
            onProgress == null ? null : (p) => onProgress(p.fraction),
      );

      final docRef = _firestore.collection('ads').doc();
      await docRef.set({
        'id': docRef.id,
        'videoUrl': videoUrl,
        'text': description,
        'imageUrls': <String>[],
        'coverImageIndex': 0,
        'imageUrl': '',
        'shopId': shopId,
        'shopOwnerId': shopOwnerId,
        'description': description,
        'mediaType': 'video',
        'durationSeconds': durationSeconds,
        'durationMinutes': durationMinutes,
        'costEGP': cost,
        'isPaid': false,
        'status': 'pending_review',
        'rejectionReason': null,
        'isActive': false,
        'isMainActive': false,
        'displayLocations': displayLocations,
        'clickCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'startDate': FieldValue.serverTimestamp(),
        'contentFlags': {
          'hasMusic': false,
          'hasWomenAppearance': false,
          'reviewedByAdmin': false,
          'adminNote': null,
        },
      });

      return {
        'success': true,
        'adId': docRef.id,
        'cost': cost,
        'durationMinutes': durationMinutes,
        'message': 'تم رفع الفيديو بنجاح وهو الآن قيد مراجعة الأدمن.\n'
            'التكلفة: ${cost.toStringAsFixed(0)} جنيه '
            '($durationMinutes دقيقة × ${videoPricePerMinute.toStringAsFixed(0)} جنيه/دقيقة)\n'
            'سيتم إشعارك عند الموافقة.',
      };
    } catch (e, s) {
      developer.log('uploadVideoAd error: $e',
          name: 'AdService', error: e, stackTrace: s);
      return {
        'success': false,
        'error': e is MediaUploadException
            ? e.userMessage
            : 'حدث خطأ أثناء رفع الفيديو، حاول مرة أخرى.'
      };
    }
  }

  static Future<void> approveVideoAd({
    required String adId,
    required bool hasMusic,
    required bool hasWomenAppearance,
    String? adminNote,
  }) async {
    final adRef = _firestore.collection('ads').doc(adId);
    final adSnap = await adRef.get();
    final adData = adSnap.data() ?? {};
    final String? videoUrl = adData['videoUrl'] as String?;
    final String? ownerId = adData['shopOwnerId'] as String?;
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

    if (hasMusic || hasWomenAppearance) {
      final reasonNote = adminNote ??
          'الفيديو لا يتوافق مع سياسة المحتوى: '
              '${hasMusic ? "يحتوي على موسيقى. " : ""}'
              '${hasWomenAppearance ? "يحتوي على ظهور نساء." : ""}';

      await adRef.update({
        'status': 'rejected',
        'isActive': false,
        'videoUrl': '',
        'contentFlags.hasMusic': hasMusic,
        'contentFlags.hasWomenAppearance': hasWomenAppearance,
        'contentFlags.reviewedByAdmin': true,
        'contentFlags.adminNote': reasonNote,
        'rejectionReason': 'مخالفة سياسة المحتوى',
      });

      if (videoUrl != null && videoUrl.isNotEmpty) {
        await MediaUploadService.deleteByUrl(videoUrl);
      }

      if (ownerId != null && ownerId.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'title': '❌ تم رفض إعلان الفيديو',
          'body': reasonNote,
          'type': 'video_ad_rejected',
          'targetUserId': ownerId,
          'fromUserId': adminUid,
          'data': {'route': 'merchant', 'channel': 'admin_alerts'},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    await adRef.update({
      'status': 'approved',
      'contentFlags.hasMusic': hasMusic,
      'contentFlags.hasWomenAppearance': hasWomenAppearance,
      'contentFlags.reviewedByAdmin': true,
      'contentFlags.adminNote': adminNote,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (ownerId != null && ownerId.isNotEmpty) {
      await _firestore.collection('notifications').add({
        'title': '✅ تمت الموافقة على إعلان الفيديو',
        'body': adminNote ?? 'تمت مراجعة الفيديو والموافقة عليه. يمكنك الآن إتمام الدفع لتفعيله.',
        'type': 'video_ad_approved',
        'targetUserId': ownerId,
        'fromUserId': adminUid,
        'data': {'route': 'merchant', 'channel': 'admin_alerts'},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> activateAdAfterPayment(
      String adId, String shopId) async {
    final existing = await _firestore
        .collection('ads')
        .where('shopId', isEqualTo: shopId)
        .where('isMainActive', isEqualTo: true)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.update({
        'isMainActive': false,
        'displayLocations': ['ads_screen'],
      });
    }

    final expiryTs = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 7)),
    );
    await _firestore.collection('ads').doc(adId).update({
      'status': 'active',
      'isActive': true,
      'isMainActive': true,
      'isPaid': true,
      'activatedAt': FieldValue.serverTimestamp(),
      'startDate': FieldValue.serverTimestamp(),
      'endDate': expiryTs,
      'expiresAt': expiryTs,
    });
  }
}
