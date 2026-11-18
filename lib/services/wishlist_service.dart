// lib/services/wishlist_service.dart
// ✅ P0-5 Fix: البحث عن المستخدم يتم عبر Cloud Function (lookupUserPublicProfile) دون كشف مجموعة users
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/wishlist_collection_model.dart';

class WishlistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // 1. إنشاء قائمة جديدة
  static Future<void> createCollection(WishlistCollection collection) async {
    String docId = collection.id.isEmpty
        ? _firestore.collection('wishlists').doc().id
        : collection.id;

    final newCollection = WishlistCollection(
      id: docId,
      name: collection.name,
      ownerId: collection.ownerId,
      collaborators: collection.collaborators,
      isPublic: collection.isPublic,
      shareToken: collection.shareToken,
      createdAt: DateTime.now(),
      items: [],
    );

    await _firestore
        .collection('wishlists')
        .doc(docId)
        .set(newCollection.toMap());
  }

  // 2. جلب قوائم المستخدم (الخاصة به + المشتركة)
  static Stream<List<WishlistCollection>> getUserCollectionsStream(
      String userId) {
    return _firestore
        .collection('wishlists')
        .where(Filter.or(
          Filter('ownerId', isEqualTo: userId),
          Filter('collaborators', arrayContains: userId),
        ))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WishlistCollection.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 3. إضافة عنصر للقائمة (محل، منتج، أو خدمة)
  static Future<void> addItemToCollection(
      String collectionId, WishlistItem item) async {
    final docRef = _firestore.collection('wishlists').doc(collectionId);

    await docRef.update({
      'items': FieldValue.arrayUnion([item.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 4. حذف عنصر من القائمة
  static Future<void> removeItemFromCollection(
      String collectionId, WishlistItem item) async {
    final docRef = _firestore.collection('wishlists').doc(collectionId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final items = List<Map<String, dynamic>>.from(
        (data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    items.removeWhere((i) =>
        (i['itemId'] ?? i['id']) == item.itemId &&
        (i['type'] ?? 'product') == item.type);
    await docRef.update({
      'items': items,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 5. حذف القائمة بالكامل
  static Future<void> deleteCollection(String collectionId) async {
    await _firestore.collection('wishlists').doc(collectionId).delete();
  }

  // 6. البحث عن مستخدم عبر Cloud Function (lookupUserPublicProfile)
  static Future<String?> findUserIdByEmail(String email) async {
    try {
      final callable = _functions.httpsCallable('lookupUserPublicProfile');
      final res = await callable.call({'query': email.trim()});
      final data = res.data;
      if (data is Map && data['found'] == true && data['id'] != null) {
        return data['id'].toString();
      }
    } catch (_) {}
    return null;
  }

  // 7. إضافة متعاون للقائمة (للمالك)
  static Future<void> addCollaborator(
      String collectionId, String userId) async {
    await _firestore.collection('wishlists').doc(collectionId).update({
      'collaborators': FieldValue.arrayUnion([userId]),
    });
  }
}
