// lib/services/ad_service.dart
// ✅ تحديث createAd() لدعم رفع صور متعددة + coverImageIndex
// ✅ توافق خلفي: لا يزال يحفظ imageUrl كـ computed value
// ✅ إصلاح الكراش: كل رفع (صور + فيديو) عبر MediaUploadService الآن —
//    تحقق من الحجم، رسائل خطأ عربية، تتبع تقدم حقيقي.
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ad_model.dart';
import 'media_upload_service.dart';

class AdService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Fix #37: إضافة limit لمنع قراءة كل الإعلانات
  // ✅ Fix #38: فلترة displayLocations لـ home screen افتراضياً
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

  // ✅ إصلاح الكراش: تفويض كامل لـ MediaUploadService — تحقق من الحجم
  // ورسائل خطأ عربية وإعادة محاولة تلقائية بدلاً من putFile الخام
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

  /// ✅ createAd مُحدَّث: يقبل قائمة صور + coverIndex + تتبع تقدم لكل صورة
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
    // ✅ نظام تقدم الرفع: (index في imageFiles, fraction 0.0–1.0)
    void Function(int fileIndex, double fraction)? onImageProgress,
  }) async {
    if (imageFiles.isEmpty) {
      throw Exception('يجب إضافة صورة واحدة على الأقل للإعلان');
    }

    // ── رفع كل الصور بالتوازي مع تتبع تقدم منفصل لكل صورة ──────────
    final imageUrls = await Future.wait(List.generate(imageFiles.length, (i) {
      return _uploadAdImage(
        imageFiles[i],
        onProgress: onImageProgress == null
            ? null
            : (f) => onImageProgress(i, f),
      );
    }));

    // ── التأكد من صحة coverIndex ─────────────────────────────────
    final validCoverIndex = coverIndex.clamp(0, imageUrls.length - 1);
    final coverImageUrl = imageUrls[validCoverIndex];

    // ── نظام الإعلان الواحد النشط لكل محل ──────────────────────
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

    await _firestore.collection('ads').add({
      // ✅ نظام الصور المتعدد
      'imageUrls': imageUrls,
      'coverImageIndex': validCoverIndex,
      // ✅ توافق خلفي
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
      'expiresAt': durationDays > 0
          ? Timestamp.fromDate(
              DateTime.now().add(Duration(days: durationDays)))
          : null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ جلب كل الإعلانات (نشطة + غير نشطة) من الأحدث للأقدم
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

  /// ✅ تحديد مكان ظهور الإعلان
  static Future<void> updateAdLocations(
      String adId, List<String> locations) async {
    await _firestore.collection('ads').doc(adId).update({
      'displayLocations': locations,
      'isMainActive':
          locations.contains('home') || locations.contains('splash'),
    });
  }

  static Future<String> generateAdCode() async {
    return 'AD_CODE_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── ضوابط الفيديوهات الترويجية ───────────────────────────────────────────

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
    // ✅ نظام تقدم الرفع: fraction 0.0–1.0
    void Function(double fraction)? onProgress,
  }) async {
    final durationError = validateVideoDuration(durationSeconds);
    if (durationError != null) {
      return {'success': false, 'error': durationError};
    }

    final cost = calculateVideoCost(durationSeconds);
    final durationMinutes = (durationSeconds / 60).ceil();

    try {
      // ✅ إصلاح الكراش: رفع آمن عبر MediaUploadService بدل putFile الخام —
      // تحقق من الحجم (≤100MB)، إعادة محاولة لأخطاء الشبكة، تتبع تقدم حقيقي
      final videoUrl = await MediaUploadService.uploadFile(
        file: videoFile,
        folder: 'ads/$shopId/pending',
        kind: MediaKind.video,
        onProgress:
            onProgress == null ? null : (p) => onProgress(p.fraction),
      );

      final docRef = await _firestore.collection('ads').add({
        'videoUrl': videoUrl,
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
        // ✅ MediaUploadException.toString() يُعيد رسالة عربية جاهزة مباشرة
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
    if (hasMusic || hasWomenAppearance) {
      await _firestore.collection('ads').doc(adId).update({
        'status': 'rejected',
        'isActive': false,
        'contentFlags.hasMusic': hasMusic,
        'contentFlags.hasWomenAppearance': hasWomenAppearance,
        'contentFlags.reviewedByAdmin': true,
        'contentFlags.adminNote': adminNote ??
            'الفيديو لا يتوافق مع سياسة المحتوى: '
                '${hasMusic ? "يحتوي على موسيقى. " : ""}'
                '${hasWomenAppearance ? "يحتوي على ظهور نساء." : ""}',
        'rejectionReason': 'مخالفة سياسة المحتوى',
      });
      return;
    }

    await _firestore.collection('ads').doc(adId).update({
      'status': 'approved',
      'contentFlags.hasMusic': hasMusic,
      'contentFlags.hasWomenAppearance': hasWomenAppearance,
      'contentFlags.reviewedByAdmin': true,
      'contentFlags.adminNote': adminNote,
      'approvedAt': FieldValue.serverTimestamp(),
    });
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

    await _firestore.collection('ads').doc(adId).update({
      'isActive': true,
      'isMainActive': true,
      'isPaid': true,
      'activatedAt': FieldValue.serverTimestamp(),
    });
  }
}
