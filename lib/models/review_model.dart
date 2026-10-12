
// lib/models/review_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String userId;
  final String targetId; // ID of the product or shop being reviewed
  final String targetType; // 'product' or 'shop'
  final int rating; // e.g., 1 to 5
  final String comment;
  final DateTime createdAt;

  // Merchant's reply
  final String? reply;
  final DateTime? repliedAt;

  // Optional data for display
  final String? userName;
  final String? userImage; // Renamed from userProfileUrl for consistency
  final String? targetName;
  final String? targetImage;
  final List<String>? images; // Images attached to the review by the user

  Review({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.targetType,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.reply,
    this.repliedAt,
    this.userName,
    this.userImage,
    this.targetName,
    this.targetImage,
    this.images,
  });

 // ✅ Fix #149: fromFirestore مع type coercion آمن
 factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Review(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      targetId: (data['targetId'] as String?) ?? '',
      targetType: (data['targetType'] as String?) ?? '',
      // ✅ Fix #149: safe num cast لمنع InvalidCastException
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      comment: (data['comment'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reply: data['reply'] as String?,
      repliedAt: (data['repliedAt'] as Timestamp?)?.toDate(),
      images: data['images'] != null
          ? List<String>.from(data['images'] as List)
          : null,
      userName: data['userName'] as String?,
      userImage: data['userImage'] as String?,
      targetName: data['targetName'] as String?,
      targetImage: data['targetImage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'targetId': targetId,
      'targetType': targetType,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'reply': reply,
      'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt!) : null,
      'images': images,
    };
  }

  Review copyWith({
    String? id,
    String? userId,
    String? targetId,
    String? targetType,
    int? rating,
    String? comment,
    DateTime? createdAt,
    String? reply,
    DateTime? repliedAt,
    String? userName,
    String? userImage,
    String? targetName,
    String? targetImage,
    List<String>? images,
    bool? isEdited,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      reply: reply ?? this.reply,
      repliedAt: repliedAt ?? this.repliedAt,
      userName: userName ?? this.userName,
      userImage: userImage ?? this.userImage,
      targetName: targetName ?? this.targetName,
      targetImage: targetImage ?? this.targetImage,
      images: images ?? this.images,
    );
  }
}
