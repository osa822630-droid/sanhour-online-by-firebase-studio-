// lib/services/review_service.dart
// ✅ P0-9 & P1-8 Fix: استخدام معرف حتمي (${userId}_${targetId}) لمنع تكرار التقييم وحساب المتوسط على الخادم عبر onReviewWritten
// ✅ P0-4 Fix: إرسال إشعار الدفع عبر NotificationService.enqueuePushNotification
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';
import 'notification_service.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> addReview(Review review) async {
    final deterministicId = '${review.userId}_${review.targetId}';
    final reviewRef = _firestore.collection('reviews').doc(deterministicId);

    final existingSnap = await reviewRef.get();
    if (existingSnap.exists) {
      throw Exception('لقد قيّمت هذا العنصر مسبقاً. يُسمح بتقييم واحد فقط.');
    }

    String? resolvedShopId = review.shopId;
    String? ownerIdToNotify;
    String targetDisplayName = review.targetName ?? 'متجرك';

    final collection = review.targetType == 'shop'
        ? 'shops'
        : (review.targetType == 'offer' ? 'offers' : 'products');
    final targetDoc =
        await _firestore.collection(collection).doc(review.targetId).get();

    if (targetDoc.exists && targetDoc.data() != null) {
      final tData = targetDoc.data()!;
      if (review.targetType == 'shop') {
        resolvedShopId = review.targetId;
        ownerIdToNotify = tData['ownerId'] as String?;
        targetDisplayName = (tData['name'] as String?) ?? targetDisplayName;
      } else {
        resolvedShopId ??= tData['shopId'] as String?;
        targetDisplayName =
            (tData['name'] ?? tData['title'])?.toString() ?? targetDisplayName;
      }
    }

    final reviewMap = {
      ...review.toMap(),
      'id': deterministicId,
      if (resolvedShopId != null && resolvedShopId.isNotEmpty)
        'shopId': resolvedShopId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await reviewRef.set(reviewMap);

    // ✅ إرسال إشعار لصاحب المحل عند إضافة تقييم جديد
    try {
      if (ownerIdToNotify == null &&
          resolvedShopId != null &&
          resolvedShopId.isNotEmpty) {
        final shopSnap =
            await _firestore.collection('shops').doc(resolvedShopId).get();
        ownerIdToNotify = shopSnap.data()?['ownerId'] as String?;
      }
      if (ownerIdToNotify != null &&
          ownerIdToNotify.isNotEmpty &&
          ownerIdToNotify != review.userId) {
        final reviewer = (review.userName != null && review.userName!.isNotEmpty)
            ? review.userName!
            : 'أحد العملاء';
        final title = '⭐ تقييم جديد (${review.rating}/5) على "$targetDisplayName"';
        final body = review.comment.isNotEmpty
            ? '$reviewer: "${review.comment.length > 70 ? '${review.comment.substring(0, 70)}...' : review.comment}"'
            : 'قام $reviewer بتقييم "$targetDisplayName" بـ ${review.rating} نجوم.';

        await _firestore.collection('notifications').add({
          'title': title,
          'body': body,
          'type': 'new_review',
          'targetUserId': ownerIdToNotify,
          'fromUserId': review.userId,
          'data': {
            'route': 'merchant_reviews',
            'shopId': resolvedShopId ?? '',
            'channel': 'merchant_reviews',
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await NotificationService.enqueuePushNotification(
          title: title,
          body: body,
          targetUserId: ownerIdToNotify,
          data: {
            'route': 'merchant_reviews',
            'shopId': resolvedShopId ?? '',
            'channel': 'merchant_reviews',
          },
        );
      }
    } catch (e) {
      developer.log('Review notification error (non-critical): $e',
          name: 'ReviewService');
    }
  }

  static Future<List<Review>> getReviews(String targetId) async {
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('targetId', isEqualTo: targetId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => Review.fromFirestore(d)).toList();
    } catch (e, s) {
      developer.log('getReviews error: $e',
          name: 'ReviewService', error: e, stackTrace: s);
      return [];
    }
  }

  static Future<void> replyToReview(String reviewId, String reply) async {
    await _firestore.collection('reviews').doc(reviewId).update({
      'reply': reply,
      'repliedAt': FieldValue.serverTimestamp(),
      'hasReply': true,
    });
  }

  static Future<bool> hasUserReviewed(
      String userId, String targetId) async {
    final deterministicDoc = await _firestore
        .collection('reviews')
        .doc('${userId}_$targetId')
        .get();
    if (deterministicDoc.exists) return true;

    final snap = await _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .where('targetId', isEqualTo: targetId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> deleteReview(
      String reviewId,
      String targetId,
      String targetType,
      int rating) async {
    await _firestore.collection('reviews').doc(reviewId).delete();
  }
}
