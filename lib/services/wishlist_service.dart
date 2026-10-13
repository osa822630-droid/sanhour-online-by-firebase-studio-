// lib/services/wishlist_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// يفضل إضافتها في pubspec.yaml لتوليد IDs لو مش هنعتمد على auto-id
import '../models/wishlist_collection_model.dart';

class WishlistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. إنشاء قائمة جديدة
  static Future<void> createCollection(WishlistCollection collection) async {
    // لو الـ ID فاضي، بنعمل واحد جديد
    String docId = collection.id.isEmpty
        ? _firestore.collection('wishlists').doc().id
        : collection.id;

    // إنشاء نسخة مع الـ ID الصحيح
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
    // للأسف Firestore لا يدعم OR query بشكل مباشر في Streams معقدة بسهولة في كل النسخ
    // الحل الأفضل والأسرع: نجيب "قوائمي" ونعرضها، وقوائم "المشاركات" ونعرضها
    // هنا هنعمل Stream يدمج الاثنين أو نعتمد على OwnerId مبدئياً
    // للتسهيل: سنجلب القوائم التي يكون فيها المستخدم هو المالك أو موجود في المتعاونين

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

    // استخدام arrayUnion لضمان عدم التكرار
    await docRef.update({
      'items': FieldValue.arrayUnion([item.toMap()])
    });
  }

  // 4. حذف عنصر من القائمة
  static Future<void> removeItemFromCollection(
      String collectionId, WishlistItem item) async {
    final docRef = _firestore.collection('wishlists').doc(collectionId);

    // ✅ Fix #34: arrayRemove يعتمد على مساواة تامة للـ Map
    // للأمان نقرأ الـ items الحالية ونحذف بالـ id بدلاً من المساواة الكاملة
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final items = List<Map<String, dynamic>>.from(
        (data['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    // ✅ Item #8: المفتاح المخزّن اسمه 'type' (WishlistItem.toMap) مش 'itemType'،
    // و WishlistItem ملهاش حقل itemType أصلًا. الـ fallbacks هنا (itemId ← id،
    // type ← 'product') هي نفس اللي WishlistItem.fromMap بيستخدمها للعناصر القديمة.
    items.removeWhere((i) =>
        (i['itemId'] ?? i['id']) == item.itemId &&
        (i['type'] ?? 'product') == item.type);
    await docRef.update({'items': items});
  }

  // 5. حذف القائمة بالكامل
  static Future<void> deleteCollection(String collectionId) async {
    await _firestore.collection('wishlists').doc(collectionId).delete();
  }

  // 6. البحث عن مستخدم لإضافته كمتعاون (Collaborator)
  // هنبحث بالإيميل أو رقم الهاتف (لأن الاسم ممكن يتكرر)
  static Future<String?> findUserIdByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
  }

  // 7. إضافة متعاون للقائمة
  static Future<void> addCollaborator(
      String collectionId, String userId) async {
    await _firestore.collection('wishlists').doc(collectionId).update({
      'collaborators': FieldValue.arrayUnion([userId])
    });
  }
}
