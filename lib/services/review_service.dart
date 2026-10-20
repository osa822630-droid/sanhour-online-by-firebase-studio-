// lib/services/review_service.dart
// ✅ Fix #27: hasUserReviewed داخل transaction لمنع race condition
// ✅ Fix #150: review.id يُعيَّن من docRef.id قبل الكتابة، fromFirestore يقرأ d.id
// ✅ Fix #194: replyToReview يُضيف hasReply: true للاستعلام السريع
// ✅ Fix #195: createdAt يُستخدم FieldValue.serverTimestamp() بدلاً من وقت الجهاز
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Fix #27: نقل hasUserReviewed داخل transaction لمنع race condition
  // ✅ Fix #150: تعيين review.id من docRef.id صريحاً قبل الكتابة
  // ✅ Fix #195: createdAt يُكتب كـ serverTimestamp
  static Future<void> addReview(Review review) async {
    // فحص مسبق سريع (non-binding pre-check فقط)
    final alreadyReviewed =
        await hasUserReviewed(review.userId, review.targetId);
    if (alreadyReviewed) {
      throw Exception('لقد قيّمت هذا العنصر مسبقاً. يُسمح بتقييم واحد فقط.');
    }

    final reviewRef = _firestore.collection('reviews').doc();

    await _firestore.runTransaction((transaction) async {
      // ✅ Fix #21: فحص "تقييم واحد لكل مستخدم" كان بيتعمل بـ query عادي جوه الـ
      // transaction *قبل* أي transaction.get، فمكنش جزء من قراءاتها — وكمان قراءة
      // وثيقة الهدف كانت بتحصل بعده: تقييمين متزامنين من نفس المستخدم (ضغطتين
      // سريعتين أو جهازين) كان الاتنين يعدّوا الفحص ويتكتبوا.
      // الـ SDK ما بيدعمش query جوه transaction ولا وثيقة بمعرّف عشوائي نقدر نعمل
      // لها tx.get، فنستخدم وثيقة الهدف (المحل/المنتج) كنقطة تسلسل: كل تقييم جديد
      // بيكتب فيها (rating / reviewCount)، فأي تقييمين متزامنين على نفس الهدف
      // بيتعارضوا عليها؛ اللي يخسر بيتعاد تلقائياً ويلاقي تقييم الأول بالفعل.
      // الشرط الوحيد: القراءة (1) تسبق الفحص (2) — لو الفحص سبقها، ممكن الطلب
      // التاني يقرأ الهدف بعد ما الأول يخلص ومنكتشفش تعارض.
      // (حالة هامشية: لو وثيقة الهدف نفسها مش موجودة مفيش كتابة عليها يعني مفيش
      // تسلسل — تقييم لعنصر محذوف، مش مسار طبيعي في التطبيق.)
      //
      // 1) القراءة: وثيقة الهدف أولاً
      final collection = review.targetType == 'shop' ? 'shops' : 'products';
      final targetRef =
          _firestore.collection(collection).doc(review.targetId);
      final targetDoc = await transaction.get(targetRef);

      // 2) الفحص: التقييم المكرر (بعد قراءة الهدف مش قبلها)
      final existingSnap = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: review.userId)
          .where('targetId', isEqualTo: review.targetId)
          .limit(1)
          .get();
      if (existingSnap.docs.isNotEmpty) {
        throw Exception('لقد قيّمت هذا العنصر مسبقاً.');
      }

      // 3) الكتابات (بعد كل القراءات)
      // ✅ Fix #150: كتابة id صريح في الوثيقة
      final reviewMap = {
        ...review.toMap(),
        'id': reviewRef.id,
        // ✅ Fix #195: serverTimestamp بدلاً من وقت الجهاز
        'createdAt': FieldValue.serverTimestamp(),
      };
      transaction.set(reviewRef, reviewMap);

      if (targetDoc.exists) {
        final data = targetDoc.data()!;
        final currentRating = (data['rating'] ?? 0.0).toDouble();
        final currentCount = (data['reviewCount'] ?? 0) as int;

        final newRating = double.parse(
          ((currentRating * currentCount + review.rating) / (currentCount + 1))
              .toStringAsFixed(1),
        );

        transaction.update(targetRef, {
          'rating': newRating,
          'reviewCount': FieldValue.increment(1),
        });
      }
    });
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

  // ✅ Fix #194: إضافة hasReply: true للاستعلام السريع مستقبلاً
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
      final collection = targetType == 'shop' ? 'shops' : 'products';
      final targetRef =
          _firestore.collection(collection).doc(targetId);
      final targetDoc = await transaction.get(targetRef);

      transaction.delete(reviewRef);

      if (targetDoc.exists) {
        final data = targetDoc.data()!;
        final currentRating = (data['rating'] ?? 0.0).toDouble();
        final currentCount = (data['reviewCount'] ?? 1) as int;

        if (currentCount > 1) {
          final newRating = double.parse(
            ((currentRating * currentCount - rating) / (currentCount - 1))
                .toStringAsFixed(1),
          );
          transaction.update(targetRef, {
            'rating': newRating,
            'reviewCount': FieldValue.increment(-1),
          });
        } else {
          transaction.update(targetRef, {'rating': 0.0, 'reviewCount': 0});
        }
      }
    });
  }
}


