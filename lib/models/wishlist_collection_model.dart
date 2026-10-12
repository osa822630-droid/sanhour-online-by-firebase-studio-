// lib/models/wishlist_collection_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WishlistCollection {
  final String id;
  final String name; // اسم القائمة (مثلاً: لبس العيد)
  final String ownerId; // صاحب القائمة
  final List<String> collaborators; // ✅ قائمة الناس المشاركة (User IDs)
  final bool isPublic; // هل القائمة عامة (للمشاركة الخارجية)؟
  final String? shareToken; // كود فريد للمشاركة الخارجية
  final DateTime createdAt;
  final List<WishlistItem> items; // العناصر اللي جوه القائمة

  WishlistCollection({
    required this.id,
    required this.name,
    required this.ownerId,
    this.collaborators = const [],
    this.isPublic = false,
    this.shareToken,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'collaborators': collaborators,
      'isPublic': isPublic,
      'shareToken': shareToken,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((x) => x.toMap()).toList(),
    };
  }

  factory WishlistCollection.fromMap(Map<String, dynamic> map, String id) {
    return WishlistCollection(
      id: id,
      name: map['name'] ?? 'قائمة جديدة',
      ownerId: map['ownerId'] ?? '',
      collaborators: List<String>.from(map['collaborators'] ?? []),
      isPublic: map['isPublic'] ?? false,
      shareToken: map['shareToken'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      items: map['items'] != null
          ? List<WishlistItem>.from(
              (map['items'] as List).map((x) => WishlistItem.fromMap(x)))
          : [],
    );
  }
}

// ✅ كلاس فرعي للعنصر المحفوظ (عشان نعرف نوعه وصورته واسمه بسرعة)
class WishlistItem {
  final String id;
  final String itemId; // ✅ Fix #157: itemId صريح لدعم removeWhere في wishlist_service
  final String type;
  final String name;
  final String imageUrl;
  final double price;
  final DateTime addedAt;

  WishlistItem({
    required this.id,
    String? itemId,
    required this.type,
    required this.name,
    required this.imageUrl,
    this.price = 0.0,
    required this.addedAt,
  }) : itemId = itemId ?? id;

  // ✅ Fix #157: Timestamp بدلاً من ISO String لاتساق مع Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'type': type,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  factory WishlistItem.fromMap(Map<String, dynamic> map) {
    // ✅ Fix #157: safe parsing لـ addedAt بكلا صيغتَي Timestamp و ISO String
    DateTime parsedAt = DateTime.now();
    final raw = map['addedAt'];
    if (raw is Timestamp) {
      parsedAt = raw.toDate();
    } else if (raw is String) {
      try { parsedAt = DateTime.parse(raw); } catch (_) {}
    }
    final id = (map['id'] as String?) ?? '';
    return WishlistItem(
      id: id,
      itemId: (map['itemId'] as String?) ?? id,
      type: (map['type'] as String?) ?? 'product',
      name: (map['name'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      addedAt: parsedAt,
    );
  }
}
