// lib/models/review_model.dart
// ✅ إصلاح toMap() لتشمل userName, userImage, targetName, targetImage, shopId
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

class Review {
  final String id;
  final String userId;
  final String targetId; // ID of the product or shop being reviewed
  final String targetType; // 'product' or 'shop'
  final String? shopId; // ID of the owning shop (for product/shop review permissions)
  final int rating; // 1 to 5
  final String comment;
  final DateTime createdAt;

  // Merchant's reply
  final String? reply;
  final DateTime? repliedAt;

  // Optional data for display
  final String? userName;
  final String? userImage;
  final String? targetName;
  final String? targetImage;
  final List<String>? images;

  Review({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.targetType,
    this.shopId,
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

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Review(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      targetId: (data['targetId'] as String?) ?? '',
      targetType: (data['targetType'] as String?) ?? '',
      shopId: data['shopId'] as String?,
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: (data['comment'] as String?) ?? '',
      createdAt: data['createdAt'] != null
          ? DateParser.parse(data['createdAt'])
          : DateTime.now(),
      reply: data['reply'] as String?,
      repliedAt: data['repliedAt'] != null
          ? DateParser.parse(data['repliedAt'])
          : null,
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
      if (shopId != null && shopId!.isNotEmpty) 'shopId': shopId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'reply': reply,
      'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt!) : null,
      'images': images,
      'userName': userName,
      'userImage': userImage,
      'targetName': targetName,
      'targetImage': targetImage,
    };
  }

  Review copyWith({
    String? id,
    String? userId,
    String? targetId,
    String? targetType,
    String? shopId,
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
      shopId: shopId ?? this.shopId,
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
