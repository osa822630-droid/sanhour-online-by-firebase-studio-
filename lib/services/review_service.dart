// lib/services/review_service.dart
// ✅ حفظ shopId داخل وثيقة التقييم لتمكين صاحب المحل من الرد على تقييمات المنتجات والمحل بأمان
// ✅ إرسال إشعار فوري لصاحب المحل عند إضافة تقييم جديد على محله أو أحد منتجاته
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> addReview(Review review) async {
    final alreadyReviewed =
        await hasUserReviewed(review.userId, review.targetId);
    if (alreadyReviewed) {
      throw Exception('لقد قيّمت هذا العنصر مسبقاً. يُسمح بتقييم واحد فقط.');
    }

    final reviewRef = _firestore.collection('reviews').doc();
    String? resolvedShopId = review.shopId;
    String? ownerIdToNotify;
    String targetDisplayName = review.targetName ?? 'متجرك';

    await _firestore.runTransaction((transaction) async {
      final collection = review.targetType == 'shop'
          ? 'shops'
          : (review.targetType == 'offer' ? 'offers' : 'products');
      final targetRef =
          _firestore.collection(collection).doc(review.targetId);
      final targetDoc = await transaction.get(targetRef);

      final existingSnap = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: review.userId)
          .where('targetId', isEqualTo: review.targetId)
          .limit(1)
          .get();
      if (existingSnap.docs.isNotEmpty) {
        throw Exception('لقد قيّمت هذا العنصر مسبقاً.');
      }

      if (targetDoc.exists) {
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
        'id': reviewRef.id,
        if (resolvedShopId != null && resolvedShopId!.isNotEmpty)
          'shopId': resolvedShopId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      transaction.set(reviewRef, reviewMap);

      if (targetDoc.exists) {
        final data = targetDoc.data()!;
        final currentRating = (data['rating'] as num? ?? 0.0).toDouble();
        final currentCount = (data['reviewCount'] as num? ?? 0).toInt();

        final newRating = double.parse(
          ((currentRating * currentCount + review.rating) / (currentCount + 1))
              .toStringAsFixed(1),
        );

        transaction.update(targetRef, {
          'rating': newRating,
          'reviewCount': currentCount + 1,
        });
      }
    });

    // ✅ إرسال إشعار لصاحب المحل عند إضافة تقييم جديد
    try {
      if (ownerIdToNotify == null &&
          resolvedShopId != null &&
          resolvedShopId!.isNotEmpty) {
        final shopSnap =
            await _firestore.collection('shops').doc(resolvedShopId).get();
        ownerIdToNotify = shopSnap.data()?['ownerId'] as String?;
      }
      if (ownerIdToNotify != null &&
          ownerIdToNotify!.isNotEmpty &&
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

        await _firestore.collection('notification_queue').add({
          'title': title,
          'body': body,
          'targetUserId': ownerIdToNotify,
          'data': {
            'route': 'merchant_reviews',
            'shopId': resolvedShopId ?? '',
            'channel': 'merchant_reviews',
          },
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 24))),
        });
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
    await _firestore.runTransaction((transaction) async {
      final reviewRef = _firestore.collection('reviews').doc(reviewId);
      final reviewDoc = await transaction.get(reviewRef);
      if (!reviewDoc.exists) {
        return;
      }
      final storedRating =
          (reviewDoc.data()?['rating'] as num?)?.toInt() ?? rating;
      final collection = targetType == 'shop'
          ? 'shops'
          : (targetType == 'offer' ? 'offers' : 'products');
      final targetRef =
          _firestore.collection(collection).doc(targetId);
      final targetDoc = await transaction.get(targetRef);

      transaction.delete(reviewRef);

      if (targetDoc.exists) {
        final data = targetDoc.data()!;
        final currentRating = (data['rating'] as num? ?? 0.0).toDouble();
        final currentCount = (data['reviewCount'] as num? ?? 1).toInt();

        if (currentCount > 1) {
          final newRating = double.parse(
            ((currentRating * currentCount - storedRating) / (currentCount - 1))
                .toStringAsFixed(1),
          );
          transaction.update(targetRef, {
            'rating': newRating,
            'reviewCount': currentCount - 1,
          });
        } else {
          transaction.update(targetRef, {'rating': 0.0, 'reviewCount': 0});
        }
      }
    });
  }
}
